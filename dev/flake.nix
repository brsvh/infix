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

    home-manager = {
      inputs = {
        nixpkgs = {
          follows = "nixpkgs";
        };
      };

      url = "git+https://github.com/nix-community/home-manager.git?ref=master";
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
  };

  outputs = _: { };
}
