{
  infix-lib,
  ...
}:
let
  inherit (infix-lib)
    hasInput
    ;

  inputs = {
    devshell = "devshell-input";
    disabled = false;
    nixpkgs = {
      source = "nixpkgs-input";
    };

    nullable = null;

    "private-ci" = {
      check = "ci-input";
    };
  };
in
{
  flake = {
    hasInput = {
      testDoesNotForceUnselectedInputs = {
        expr = hasInput (
          inputs
          // {
            broken = throw "unselected input was forced";
          }
        ) "devshell";

        expected = "devshell-input";
      };

      testReportsEmptyInputs = {
        expr = hasInput { } "nixpkgs";

        expectedError = {
          msg = "nixpkgs input not found, please add a nixpkgs input to your flake.";
          type = "ThrownError";
        };
      };

      testReportsMissingInputName = {
        expr = hasInput inputs "flake-parts";

        expectedError = {
          msg = "flake-parts input not found, please add a flake-parts input to your flake.";
          type = "ThrownError";
        };
      };

      testReturnsExistingAttrsInput = {
        expr = hasInput inputs "nixpkgs";

        expected = {
          source = "nixpkgs-input";
        };
      };

      testReturnsExistingFalseInput = {
        expr = hasInput inputs "disabled";

        expected = false;
      };

      testReturnsExistingNullInput = {
        expr = hasInput inputs "nullable";

        expected = null;
      };

      testReturnsExistingStringInput = {
        expr = hasInput inputs "devshell";

        expected = "devshell-input";
      };

      testReturnsInputWithQuotedName = {
        expr = hasInput inputs "private-ci";

        expected = {
          check = "ci-input";
        };
      };
    };
  };
}
