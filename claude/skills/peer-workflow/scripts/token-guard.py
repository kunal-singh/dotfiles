#!/usr/bin/env python3
# Run by the peer-workflow skill's frontmatter hooks (UserPromptSubmit, PreToolUse
# Agent|SendMessage, SubagentStop), active once the skill is invoked. Token-hygiene guard.
"""Token-hygiene hooks, dispatched on the hook event in the stdin payload.

- UserPromptSubmit: warns when live context passes NUDGE_PCT of CONTEXT_WINDOW (compaction alert).
- PreToolUse/Agent: reminds to use Sonnet and a narrow scope when no model is set.
- PreToolUse/SendMessage: asks before resuming a subagent whose context is large.
- SubagentStop: reports the finished subagent's calls, cache reads and peak context.

It never blocks on its own failure: any error prints nothing and exits 0.
"""
import glob
import json
import os
import sys

# Owner, 2026-11-12: 200k is 25% of the window, so the window is 800k. Override with
# TOKEN_GUARD_WINDOW (tokens) if the model's window differs.
CONTEXT_WINDOW = int(os.environ.get('TOKEN_GUARD_WINDOW', 800_000))
NUDGE_PCT = 0.80             # share of the window that triggers the compaction alert
RESUME_LIMIT = 150_000       # subagent context above which a resume needs approval


def usage_stats(path):
    """(calls, cache_read_total, last_context, peak_context) for a transcript JSONL."""
    seen, calls, cache_read, last, peak = set(), 0, 0, 0, 0
    with open(path) as fh:
        for line in fh:
            try:
                d = json.loads(line)
            except ValueError:
                continue
            if d.get('type') != 'assistant':
                continue
            m = d.get('message') or {}
            u = m.get('usage') or {}
            key = (m.get('id'), d.get('requestId'))
            if not u or key in seen:
                continue
            seen.add(key)
            ctx = (u.get('input_tokens', 0) + u.get('cache_read_input_tokens', 0)
                   + u.get('cache_creation_input_tokens', 0))
            calls += 1
            cache_read += u.get('cache_read_input_tokens', 0)
            last, peak = ctx, max(peak, ctx)
    return calls, cache_read, last, peak


def emit(obj):
    print(json.dumps(obj))


def on_prompt(p):
    path = p.get('transcript_path')
    if not path or not os.path.exists(path):
        return
    _, _, last, _ = usage_stats(path)
    pct = last / CONTEXT_WINDOW
    if pct < NUDGE_PCT:
        return
    k = last // 1000
    emit({
        'systemMessage': f'Context is ~{k}k tokens, {pct:.0%} of the window (alert at '
                         f'{NUDGE_PCT:.0%}). Compaction is near: hand off from the resume doc.',
        'hookSpecificOutput': {
            'hookEventName': 'UserPromptSubmit',
            'additionalContext': (
                f'Token guard: this session\'s context is about {k}k tokens, {pct:.0%} of the '
                'window, so compaction is near. Before starting new work, bring the resume '
                'document up to date and suggest a fresh session from it.'),
        },
    })


def on_agent(p):
    ti = p.get('tool_input') or {}
    if ti.get('subagent_type') == 'fork' or ti.get('model'):
        return
    emit({'hookSpecificOutput': {
        'hookEventName': 'PreToolUse',
        'additionalContext': (
            'Token guard: this Agent call sets no model, so it runs on the session model. '
            'That is right for judgment work (reviews, design calls, security-sensitive '
            'changes). Only if this helper\'s work is mechanical (applying decided doc edits, '
            'renames, bulk changes) set model "sonnet". Either way, scope it to one '
            'section/task and its own findings (aim < 150k context); never resume a large '
            'helper.'),
    }})


def on_send(p):
    ti = p.get('tool_input') or {}
    to = str(ti.get('to') or '').split(' ')[0]
    if not to.startswith('a') or not p.get('transcript_path'):
        return
    sess_dir = os.path.splitext(p['transcript_path'])[0]
    path = os.path.join(sess_dir, 'subagents', f'agent-{to}.jsonl')
    if not os.path.exists(path):
        return
    _, _, last, _ = usage_stats(path)
    if last < RESUME_LIMIT:
        return
    emit({'hookSpecificOutput': {
        'hookEventName': 'PreToolUse',
        'permissionDecision': 'ask',
        'permissionDecisionReason': (
            f'Resuming subagent {to}, whose context is ~{last // 1000}k tokens; every call it '
            'makes re-reads that. A fresh, narrowly scoped helper is usually cheaper.'),
    }})


def on_subagent_stop(p):
    path = p.get('agent_transcript_path')
    if not path and p.get('transcript_path'):
        sub = os.path.join(os.path.splitext(p['transcript_path'])[0], 'subagents')
        files = glob.glob(os.path.join(sub, 'agent-*.jsonl'))
        path = max(files, key=os.path.getmtime) if files else None
    if not path or not os.path.exists(path):
        return
    calls, cache_read, _, peak = usage_stats(path)
    if calls == 0:
        return
    msg = (f'Subagent {os.path.basename(path)[6:16]}: {calls} calls, '
           f'{cache_read / 1e6:.1f}M cache read, peak context {peak // 1000}k.')
    if peak >= RESUME_LIMIT:
        msg += ' Large: do not resume it; use a fresh, narrow helper next time.'
    emit({'systemMessage': msg})


def main():
    try:
        p = json.load(sys.stdin)
    except ValueError:
        return
    event = p.get('hook_event_name')
    tool = p.get('tool_name')
    if event == 'UserPromptSubmit':
        on_prompt(p)
    elif event == 'PreToolUse' and tool == 'Agent':
        on_agent(p)
    elif event == 'PreToolUse' and tool == 'SendMessage':
        on_send(p)
    elif event == 'SubagentStop':
        on_subagent_stop(p)


if __name__ == '__main__':
    try:
        main()
    except Exception:  # noqa: BLE001 - a guard must never break the session
        pass
