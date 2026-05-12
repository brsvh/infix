{
  infix-lib,
  lib,
  ...
}:
let
  inherit (infix-lib)
    mapAttrsRecursive'
    mapAttrsRecursiveCond'
    ;

  inherit (lib)
    concatStringsSep
    isAttrs
    last
    nameValuePair
    ;

  pathString = path: concatStringsSep "." path;

  renameWithPathValue =
    path: value:
    nameValuePair "mapped-${last path}" (
      if isAttrs value then value else pathString path
    );

  collapseMarkedAttrs =
    path: value:
    nameValuePair "mapped-${last path}" (
      if
        isAttrs value
        && (value ? collapse)
        && value.collapse
      then
        "collapsed:${pathString path}"
      else if isAttrs value then
        value
      else
        pathString path
    );

  markFooNonRecursive =
    path: value:
    nameValuePair "mapped-${last path}" (
      if isAttrs value && path == [ "foo" ] then
        value
        // {
          recurse = false;
        }
      else if isAttrs value then
        value
      else
        pathString path
    );
in
{
  attrsets = {
    mapAttrsRecursive' = {
      testCollapsesAttrsetWhenMapperReturnsLeaf = {
        expr = mapAttrsRecursive' collapseMarkedAttrs {
          foo = {
            bar = "baz";
            collapse = true;
          };

          qux = {
            baz = "quux";
          };
        };

        expected = {
          mapped-foo = "collapsed:foo";

          mapped-qux = {
            mapped-baz = "mapped-qux.baz";
          };
        };
      };

      testKeepsEmptyAttrsets = {
        expr = mapAttrsRecursive' renameWithPathValue {
          empty = { };

          nested = {
            empty = { };
          };
        };

        expected = {
          mapped-empty = { };

          mapped-nested = {
            mapped-empty = { };
          };
        };
      };

      testRenamesNestedAttrs = {
        expr = mapAttrsRecursive' renameWithPathValue {
          foo = {
            bar = "baz";
          };

          qux = "quux";
        };

        expected = {
          mapped-foo = {
            mapped-bar = "mapped-foo.bar";
          };

          mapped-qux = "qux";
        };
      };
    };

    mapAttrsRecursiveCond' = {
      testCanDisableAllNestedRecursion = {
        expr =
          mapAttrsRecursiveCond' (_: false)
            renameWithPathValue
            {
              foo = {
                bar = "baz";
              };

              qux = "quux";
            };

        expected = {
          mapped-foo = {
            bar = "baz";
          };

          mapped-qux = "qux";
        };
      };

      testPredicateSeesMappedValue = {
        expr =
          mapAttrsRecursiveCond'
            (
              attrs:
              !(attrs ? recurse && attrs.recurse == false)
            )
            markFooNonRecursive
            {
              foo = {
                bar = "baz";
              };

              qux = {
                baz = "quux";
              };
            };

        expected = {
          mapped-foo = {
            bar = "baz";
            recurse = false;
          };

          mapped-qux = {
            mapped-baz = "mapped-qux.baz";
          };
        };
      };

      testRecursesWhenPredicateAllows = {
        expr =
          mapAttrsRecursiveCond' (_: true)
            renameWithPathValue
            {
              foo = {
                bar = "baz";
              };

              qux = "quux";
            };

        expected = {
          mapped-foo = {
            mapped-bar = "mapped-foo.bar";
          };

          mapped-qux = "qux";
        };
      };

      testStopsAtPredicate = {
        expr =
          mapAttrsRecursiveCond'
            (attrs: !(attrs ? stop && attrs.stop))
            renameWithPathValue
            {
              foo = {
                bar = "baz";
                stop = true;
              };

              qux = {
                baz = "quux";
              };
            };

        expected = {
          mapped-foo = {
            bar = "baz";
            stop = true;
          };

          mapped-qux = {
            mapped-baz = "mapped-qux.baz";
          };
        };
      };
    };
  };
}
