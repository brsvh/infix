{
  inputs = {
    agent-skills = {
      inputs = {
        home-manager = {
          follows = "home-manager";
        };

        nixpkgs = {
          follows = "nixpkgs";
        };
      };

      url = "git+https://github.com/Kyure-A/agent-skills-nix.git?ref=master";
    };

    bingshan-skills = {
      flake = false;
      url = "git+https://codeberg.org/bingshan/skills.git?ref=main";
    };

    blank = {
      url = "git+https://github.com/divnix/blank.git?ref=master";
    };

    blueprint = {
      inputs = {
        nixpkgs = {
          follows = "nixpkgs";
        };

        systems = {
          follows = "systems";
        };
      };

      url = "git+https://github.com/numtide/blueprint.git?ref=main";
    };

    bun = {
      inputs = {
        flake-parts = {
          follows = "flake-parts";
        };

        nixpkgs = {
          follows = "nixpkgs";
        };

        systems = {
          follows = "systems";
        };

        treefmt-nix = {
          follows = "blank";
        };
      };

      url = "git+https://github.com/nix-community/bun2nix.git?ref=master";
    };

    flake-parts = {
      inputs = {
        nixpkgs-lib = {
          follows = "nixpkgs";
        };
      };

      url = "git+https://github.com/hercules-ci/flake-parts.git?ref=main";
    };

    home-manager = {
      inputs = {
        nixpkgs = {
          follows = "nixpkgs";
        };
      };

      url = "git+https://github.com/nix-community/home-manager.git?ref=master";
    };

    llm-agents = {
      inputs = {
        blueprint = {
          follows = "blueprint";
        };

        bun2nix = {
          follows = "bun";
        };

        flake-parts = {
          follows = "flake-parts";
        };

        nixpkgs = {
          follows = "nixpkgs";
        };

        systems = {
          follows = "systems";
        };

        treefmt-nix = {
          follows = "blank";
        };
      };

      url = "git+https://github.com/numtide/llm-agents.nix?ref=main";
    };

    nix-unit = {
      inputs = {
        nix-github-actions = {
          follows = "blank";
        };

        nixpkgs = {
          follows = "nixpkgs";
        };

        treefmt-nix = {
          follows = "blank";
        };
      };

      url = "git+https://github.com/nix-community/nix-unit.git?ref=main";
    };

    nixpkgs = {
      url = "git+https://github.com/NixOS/nixpkgs.git?ref=nixpkgs-unstable";
    };

    openai-skills = {
      flake = false;
      url = "git+https://github.com/openai/skills.git?ref=main";
    };

    systems = {
      url = "git+https://github.com/nix-systems/x86_64-linux.git?ref=main";
    };
  };

  outputs = _: { };
}
