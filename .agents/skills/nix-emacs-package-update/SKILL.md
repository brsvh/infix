---
name: nix-emacs-package-update
description: >-
  Check and update one existing Emacs Lisp package under this repository's
  src/emacs-packages/manual-packages. Use when the user invokes
  $nix-emacs-package-update PACKAGE or asks to check, update, or bump a single
  manual Emacs package pin, revision, hash, or version. Do not use for bulk
  updates across all manual-packages.
compatibility: >-
  Requires nix, nix-prefetch-git, and outgoing network access to fetch Git
  refs. The target repository must be an Infix Nix flake checkout.
---

# Nix Emacs Package Update

Check one existing package at
`src/emacs-packages/manual-packages/<pname>/package.nix` against the current
default branch head of its `src.url`.

## Required Input

Require exactly one package name such as `foo-bar`. If the user does not provide
a package name, ask one concise follow-up question. Do not scan or update every
manual package unless the user explicitly asks for a different workflow.

Work from the repository root. The target file is:

```
src/emacs-packages/manual-packages/<pname>/package.nix
```

If the file does not exist, report that directly and make no changes.

## Tool Setup

Use the repository's available tools when present. When a required command is
missing, run it through a temporary Nix environment:

```
nix shell nixpkgs#nix-prefetch-git -c nix-prefetch-git --quiet --url <url>
nix shell nixpkgs#treefmt nixpkgs#nixfmt-rfc-style -c treefmt <package.nix>
```

If `nix` itself is unavailable, report that as a blocker.

If `nix-prefetch-git` fails because network access is sandboxed, rerun it with
the appropriate approval rather than treating the package as up to date.

## Workflow

1. Inspect the current package expression.

   Extract these values from the `src = fetchgit { ... };` block:

   - `src.url`
   - `src.rev`
   - `src.hash`

   Also record the current `version` binding.

2. Fetch the current upstream default branch head:

   ```
   nix-prefetch-git --quiet --url <url>
   ```

   Use the returned JSON fields:

   - `rev`
   - `hash`
   - `path`
   - `date`, when version fallback needs a commit date

3. Compare revisions.

   If the returned `rev` equals the current `src.rev`, make no package changes.
   Report that the package is already current and include the checked revision.

4. If the returned `rev` differs, inspect the fetched source at the returned
   `path` before editing.

   Determine whether `version` needs an update from source evidence:

   - Prefer the main file `<pname>.el` when present.
   - Otherwise inspect the primary package file whose header line is
     `;;; <name>.el --- ...`.
   - Check package headers such as `;; Version:`, `;; Package-Version:`, and
     generated `define-package` forms when present.
   - If the source-declared version differs from the Nix `version`, update the
     Nix `version`.
   - If no source-declared version exists and the current Nix version is
     `unstable-YYYY-MM-DD`, update the date from the fetched commit `date`.
   - If no source-declared version exists and the current version is a normal
     release version, do not invent a new version. Keep the current version and
     state that no source version evidence required a change.

5. Edit only the target package file.

   Follow `$nix-code-refactor` conventions when changing `.nix` code. Keep the
   edit limited to:

   - `version`, only when source evidence requires it;
   - `src.rev`;
   - `src.hash`.

   Do not refactor unrelated package structure, dependencies, metadata, or
   formatting.

6. Format the changed file with the repository formatter:

   ```
   treefmt src/emacs-packages/manual-packages/<pname>/package.nix
   ```

   Use the temporary Nix environment fallback from Tool Setup if `treefmt` or
   `nixfmt` is missing.

## Validation

Evaluate the updated package version through the Emacs package overlay:

```
nix eval --impure --expr 'let flake = builtins.getFlake (toString ./.); pkgs = import flake.inputs.nixpkgs { system = builtins.currentSystem; overlays = [ flake.overlays.emacs-packages ]; }; in pkgs.emacsPackages.<pname>.version'
```

Build the package through the same overlay without creating a `result` symlink:

```
nix build --no-link --impure --expr 'let flake = builtins.getFlake (toString ./.); pkgs = import flake.inputs.nixpkgs { system = builtins.currentSystem; overlays = [ flake.overlays.emacs-packages ]; }; in pkgs.emacsPackages.<pname>'
```

Run `git diff --check` after edits.

If evaluation or build fails because a dependency is missing or the upstream
source changed build requirements, inspect the failure and make the smallest
package-local fix that is clearly required. If the fix would require adding or
updating another manual package, stop and ask the user whether to include that
additional package work.

## Final Response

Report:

- target package path;
- whether the upstream rev changed;
- old and new `src.rev` and `src.hash` when updated;
- version decision and the source evidence used;
- validation commands run and their results;
- any blockers or weak evidence.
