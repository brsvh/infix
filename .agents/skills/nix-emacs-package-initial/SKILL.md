---
name: nix-emacs-package-initial
description: >-
  Package a new Emacs Lisp repository into this repository's
  src/emacs-packages/manual-packages using a Nix melpaBuild expression. Use
  when the user invokes $nix-emacs-package-initial or asks to add or package an
  Emacs Lisp package from a git repository into manual-packages. Require the
  user to provide a repository URL before changing package files.
compatibility: >-
  Requires nix, nix-prefetch-git, and outgoing network access to fetch Git
  refs. The target repository must be an Infix Nix flake checkout.
---

# Nix Emacs Package Initial

Use this skill to add a git-hosted Emacs Lisp package under
`src/emacs-packages/manual-packages`.

## Required Input

Require a repository URL in the user's request. If the request does not include
a URL, ask one concise follow-up question and do not create files yet.

Optional inputs may include package name, revision, version, description,
license, homepage, or dependencies. Infer missing values from the repository
when practical, and state any material assumption in the final answer.

## Tool Setup

Use the repository's available tools when present. When a required command is
missing, run it through a temporary Nix environment:

```
nix shell nixpkgs#nix-prefetch-git -c nix-prefetch-git --quiet --url <url>
nix shell nixpkgs#treefmt nixpkgs#nixfmt-rfc-style -c treefmt <package.nix>
```

If `nix` itself is unavailable, report that as a blocker.

If `nix-prefetch-git` fails because network access is sandboxed, rerun it with
the appropriate approval rather than failing.

## Workflow

01. Work from the repository root.

02. Inspect nearby package expressions in `src/emacs-packages/manual-packages`.

03. Use `$nix-coding` when writing or changing `.nix` code.

04. Determine the package name:

    - Prefer the main Emacs Lisp package name from the source.
    - Otherwise derive it from the repository name by removing common prefixes
      such as `emacs-` and suffixes such as `.el`.
    - Use the same value for the directory name and `pname` unless the source
      package header gives a more precise package name.

05. Fetch and pin the source:

    ```sh
    nix-prefetch-git --url <repository-url> --rev <revision> --quiet
    ```

    If no revision is supplied, use the repository's current default branch
    head:

    ```sh
    nix-prefetch-git --url <repository-url> --quiet
    ```

    Use the returned `rev` and SRI `hash` when available. If only `sha256` is
    returned, use that hash value.

06. Inspect the fetched source path from `nix-prefetch-git`:

    - Read the main `.el` file headers for `Package-Requires`, `Version`,
      `Package-Version`, `URL`, and `Keywords`.
    - Ignore the Emacs version requirement as a propagated package dependency.
    - Treat built-in Emacs libraries as built-ins unless this repository already
      packages them explicitly.
    - Map required package names to Emacs package attributes available in the
      package scope.
    - Read the license file or source header to choose `lib.licenses.*`.

07. Create `src/emacs-packages/manual-packages/<pname>/package.nix`.

08. Follow the local manual package pattern:

    ```nix
    {
      dependency-one,
      fetchgit,
      lib,
      melpaBuild,
      ...
    }:
    let
      inherit (lib)
        licenses
        maintainers
        ;

      version = "0.1.0";

      src = fetchgit {
        url = "https://example.org/user/package.git";
        rev = "<commit>";
        hash = "sha256-...";
      };

      meta = {
        description = "Short package description";
        homepage = "https://example.org/user/package";
        license = licenses.gpl3Plus;
        maintainers = with maintainers; [ brsvh ];
      };
    in
    melpaBuild {
      inherit
        meta
        src
        version
        ;

      pname = "package-name";

      packageRequires = [
        dependency-one
      ];
    }
    ```

09. Keep `packageRequires` empty only when the package has no non-built-in
    runtime dependencies:

    ```nix
    packageRequires = [ ];
    ```

10. Add special build hooks only when source inspection or a failed build shows
    they are needed. Prefer the smallest local fix over broad environment
    changes.

## Validation

Format changed Nix files with the repository formatter:

```sh
treefmt src/emacs-packages/manual-packages/<pname>/package.nix
```

Evaluate the package through the Emacs package overlay:

```sh
nix eval --impure --expr 'let flake = builtins.getFlake (toString ./.); pkgs = import flake.inputs.nixpkgs { system = builtins.currentSystem; overlays = [ flake.overlays.emacs-packages ]; }; in pkgs.emacsPackages.<pname>.pname'
```

Build the package through the same overlay without creating a `result` symlink:

```sh
nix build --no-link --impure --expr 'let flake = builtins.getFlake (toString ./.); pkgs = import flake.inputs.nixpkgs { system = builtins.currentSystem; overlays = [ flake.overlays.emacs-packages ]; }; in pkgs.emacsPackages.<pname>'
```

If evaluation or build fails because a dependency is missing, determine whether
the dependency is already available under `pkgs.emacsPackages`. If it is not,
package the dependency first or ask the user whether to include that additional
package work.

## Final Response

Report the created package path, pinned revision, selected version, dependency
set, and validation commands run. If any value was inferred from weak evidence,
state that explicitly.
