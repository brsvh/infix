{
  infix-lib,
  projectRoot,
  ...
}:
let
  inherit (infix-lib)
    dirToAttrs
    dirsToAttrs
    hasDirectory
    hasFile
    readDir
    stemOf
    ;

  fixtureDir =
    projectRoot + "/test/fixtures/filesystem";

  leftMergeDir = fixtureDir + "/merge/left";

  libDir = projectRoot + "/lib";

  metadataCollisionDir =
    fixtureDir + "/metadata-collision";

  rightMergeDir = fixtureDir + "/merge/right";

  testDir = projectRoot + "/test";
in
{
  filesystem = {
    dirToAttrs = {
      testExposesDirectoryPathMetadata = {
        expr =
          let
            attrs = dirToAttrs projectRoot;
          in
          {
            lib = attrs.lib.__path;
            root = attrs.__path;
            test = attrs.test.__path;
          };

        expected = {
          lib = libDir;
          root = projectRoot;
          test = testDir;
        };
      };

      testKeepsRegularFilesAsPaths = {
        expr =
          let
            attrs = dirToAttrs projectRoot;
          in
          {
            default = attrs.lib."default.nix";
            flake = attrs."flake.nix";
            filesystem = attrs.lib."filesystem.nix";
            test = attrs.test."default.nix";
          };

        expected = {
          default = libDir + "/default.nix";
          flake = projectRoot + "/flake.nix";
          filesystem = libDir + "/filesystem.nix";
          test = testDir + "/default.nix";
        };
      };

      testRecursesIntoNestedDirectories = {
        expr =
          let
            attrs = dirToAttrs projectRoot;
          in
          {
            default = attrs.lib."default.nix";
            filesystem = attrs.lib."filesystem.nix";
            module = attrs.src."flake-modules"."lib.nix";
          };

        expected = {
          default = libDir + "/default.nix";
          filesystem = libDir + "/filesystem.nix";
          module =
            projectRoot + "/src/flake-modules/lib.nix";
        };
      };

      testRejectsPathMetadataCollision = {
        expr = dirToAttrs metadataCollisionDir;

        expectedError = {
          msg = "contains an entry named __path";
          type = "ThrownError";
        };
      };
    };

    dirsToAttrs = {
      testAcceptsPathMetadataFileName = {
        expr = dirsToAttrs [
          metadataCollisionDir
        ];

        expected = {
          __path = metadataCollisionDir + "/__path";
        };
      };

      testDoesNotAddPathMetadata = {
        expr =
          let
            attrs = dirsToAttrs [
              leftMergeDir
            ];
          in
          {
            nested = attrs.a ? __path;
            root = attrs ? __path;
          };

        expected = {
          nested = false;
          root = false;
        };
      };

      testEmptyInputReturnsEmptyAttrs = {
        expr = dirsToAttrs [ ];

        expected = { };
      };

      testIncludesHiddenFiles = {
        expr =
          (dirsToAttrs [
            leftMergeDir
          ]).".hidden.nix";

        expected = leftMergeDir + "/.hidden.nix";
      };

      testLaterDirectoryOverridesEarlierFile = {
        expr =
          (dirsToAttrs [
            leftMergeDir
            rightMergeDir
          ]).conflict-file;

        expected = {
          "nested-right.nix" =
            rightMergeDir + "/conflict-file/nested-right.nix";
        };
      };

      testLaterFileOverridesEarlierDirectory = {
        expr =
          (dirsToAttrs [
            leftMergeDir
            rightMergeDir
          ]).conflict-dir;

        expected = rightMergeDir + "/conflict-dir";
      };

      testLaterFilesOverrideEarlierFiles = {
        expr =
          (dirsToAttrs [
            leftMergeDir
            rightMergeDir
          ])."common.nix";

        expected = rightMergeDir + "/common.nix";
      };

      testMergesNestedDirectories = {
        expr =
          let
            attrs = dirsToAttrs [
              leftMergeDir
              rightMergeDir
            ];
          in
          {
            inherit (attrs)
              a
              shared-dir
              ;
          };

        expected = {
          a = {
            "b.nix" = leftMergeDir + "/a/b.nix";
            "d.nix" = rightMergeDir + "/a/d.nix";
            "shared.nix" = rightMergeDir + "/a/shared.nix";
          };

          shared-dir = {
            "left.nix" =
              leftMergeDir + "/shared-dir/left.nix";
            "right.nix" =
              rightMergeDir + "/shared-dir/right.nix";
          };
        };
      };

      testMergesTopLevelFiles = {
        expr =
          let
            attrs = dirsToAttrs [
              leftMergeDir
              rightMergeDir
            ];
          in
          {
            "b.nix" = attrs."b.nix";
            "c.nix" = attrs."c.nix";
            "e.nix" = attrs."e.nix";
          };

        expected = {
          "b.nix" = leftMergeDir + "/b.nix";
          "c.nix" = rightMergeDir + "/c.nix";
          "e.nix" = rightMergeDir + "/e.nix";
        };
      };

      testReverseOrderChangesWinningFile = {
        expr =
          (dirsToAttrs [
            rightMergeDir
            leftMergeDir
          ])."common.nix";

        expected = leftMergeDir + "/common.nix";
      };
    };

    hasDirectory = {
      testReturnsFalseForMissingEntry = {
        expr = hasDirectory projectRoot "missing";
        expected = false;
      };

      testReturnsFalseForRegularFile = {
        expr = hasDirectory projectRoot "flake.nix";
        expected = false;
      };

      testReturnsTrueForDirectory = {
        expr = {
          lib = hasDirectory projectRoot "lib";
          test = hasDirectory projectRoot "test";
        };

        expected = {
          lib = true;
          test = true;
        };
      };
    };

    hasFile = {
      testReturnsFalseForDirectory = {
        expr = hasFile projectRoot "lib";
        expected = false;
      };

      testReturnsFalseForMissingEntry = {
        expr = hasFile projectRoot "missing.nix";
        expected = false;
      };

      testReturnsTrueForRegularFile = {
        expr = {
          flake = hasFile projectRoot "flake.nix";
          filesystem = hasFile libDir "filesystem.nix";
        };

        expected = {
          flake = true;
          filesystem = true;
        };
      };
    };

    readDir = {
      testReadsDirectoryEntries = {
        expr =
          let
            entries = readDir projectRoot;
          in
          {
            flake = entries."flake.nix";
            lib = entries.lib;
            test = entries.test;
          };

        expected = {
          flake = "regular";
          lib = "directory";
          test = "directory";
        };
      };

      testReadsNestedDirectoryEntries = {
        expr =
          let
            entries = readDir libDir;
          in
          {
            attrsets = entries."attrsets.nix";
            default = entries."default.nix";
            filesystem = entries."filesystem.nix";
          };

        expected = {
          attrsets = "regular";
          default = "regular";
          filesystem = "regular";
        };
      };
    };

    stemOf = {
      testKeepsDotfilesUnchanged = {
        expr = {
          env = stemOf ".env";
          profile = stemOf ".profile.nix";
        };

        expected = {
          env = ".env";
          profile = ".profile.nix";
        };
      };

      testKeepsNamesWithoutExtension = {
        expr = {
          directory = stemOf ./attrsets.nix;
          name = stemOf "Makefile";
        };

        expected = {
          directory = "attrsets";
          name = "Makefile";
        };
      };

      testRemovesOnlyFinalExtension = {
        expr = {
          archive = stemOf "archive.tar.gz";
          default = stemOf "default.nix";
        };

        expected = {
          archive = "archive.tar";
          default = "default";
        };
      };
    };
  };
}
