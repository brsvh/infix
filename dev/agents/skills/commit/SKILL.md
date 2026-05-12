---
name: commit
description: >-
  Commit the staged changes in this repository using the repository's commit
  message rules.
---

# Commit

Use this skill when the user wants the staged changes committed.

## Required workflow

Run these commands in order from the repo root:

1. `git status --short`
1. `git diff --cached --stat`
1. `git diff --cached`

Do not skip these checks.

If nothing is staged, say so clearly and stop.

1. Complete the required workflow above.
1. Draft the final commit message using the repository rules below.
1. Check the final message text using the checklist below.
1. Write the message to a temporary file and run
   `git commit -F <temporary-file>`.
1. Report the commit result, including the new commit hash when available.

Do not pause after the user's explicit commit request. Treat that request as
authorization to create the commit. If the environment blocks access to `.git`,
retry with the required sandbox escalation and continue after access is
available.

## Repository rules

Follow `dev/agents/docs/commit-message-style.md`.

Hard requirements:

- describe staged changes only;
- use only `scope: Verb summary` or `scope: subscope: Verb summary`;
- derive scope from staged paths and staged diff;
- keep scope tokens lowercase;
- use an imperative capitalized verb;
- omit the trailing period in the subject;
- always include a body after exactly one blank line;
- write the body as `* path: change.` bullets;
- sort bullets by path in ascending lexicographic order;
- keep bullets concise and file-oriented;
- wrap body lines to at most 70 columns in GNU style without indenting
  continuation lines;
- after the body bullets, add exactly one blank line and then a final
  `Assisted-by:` trailer.

The required trailer format is:

```text
Assisted-by: AGENT_NAME:MODEL_VERSION [TOOL1] [TOOL2]
```

Fill `AGENT_NAME` and `MODEL_VERSION` at skill invocation time using the actual
agent name and the most specific model version available from the active session
context. `MODEL_VERSION` should be a precise model label such as `GPT-5.5`, not
a coarse family label such as `GPT-5`, when the precise label is available. Do
not hard-code either value in this skill. Omit tool tokens unless a specialized
analysis tool was actually called while preparing the commit. Do not list
routine shell, git, formatter, patching, or commit-skill operations as tools.

Before producing or committing a message, check the final message text:

- the subject must use one allowed scope form;
- exactly one blank line must separate the subject from the body;
- every body line must be 70 columns or shorter;
- wrapped bullet continuations must start at column 0;
- every bullet must end with a period;
- the final line must be the `Assisted-by:` trailer, with no trailing blank
  line.

## Output format

Do not output only a proposed message. Commit with the generated message first,
then report the result.
