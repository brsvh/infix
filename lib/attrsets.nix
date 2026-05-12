/**
  Attribute set manipulation functions.
*/
{
  lib,
  ...
}:
let
  inherit (lib)
    isAttrs
    mapAttrs'
    nameValuePair
    ;
in
rec {
  /**
    Like `mapAttrsRecursive`, but the mapping function returns a name-value
    pair, allowing attributes to be renamed while they are mapped.

    # Inputs

    `f`
    : Mapping function that receives an attribute path and value, and returns a
      name-value pair.

      The first argument to the mapping function is a list of attribute
      names forming the path to the current attribute. The second argument is
      the current attribute value.

    `attrs`
    : Attribute set to map over.

    # Type

    ```
    mapAttrsRecursive' :: ([String] -> a -> { name :: String; value :: b; }) -> AttrSet -> AttrSet
    ```

    # Examples
    :::{.example}
    ## `infix-lib.mapAttrsRecursive'` usage example

    ```nix
    mapAttrsRecursive'
      (path: value: nameValuePair "renamed-${last path}" value)
      {
        foo = {
          bar = "baz";
        };
      }
    => {
      "renamed-foo" = {
        "renamed-bar" = "baz";
      };
    }
    ```

    :::
  */
  mapAttrsRecursive' =
    f: mapAttrsRecursiveCond' (_: true) f;

  /**
    Like `mapAttrsRecursive'`, but it takes an additional predicate that
    tells it whether to recurse into a mapped attribute set.

    If the predicate returns false, `mapAttrsRecursiveCond'` does not
    recurse, and instead keeps the mapped name-value pair as a leaf.

    # Inputs

    `cond`
    : Predicate that decides whether to recurse into a mapped attribute set.

      If the predicate returns true, `mapAttrsRecursiveCond'` recurses into
      the mapped attribute set. If the predicate returns false, it treats the
      mapped attribute set as a leaf.

    `f`
    : Mapping function that receives an attribute path and value, and returns a
      name-value pair.

      The first argument to the mapping function is a list of attribute
      names forming the path to the current attribute. The second argument is
      the current attribute value.

    `attrs`
    : Attribute set to map over.

    # Type

    ```
    mapAttrsRecursiveCond' :: (AttrSet -> Bool) -> ([String] -> a -> { name :: String; value :: b; }) -> AttrSet -> AttrSet
    ```

    # Examples
    :::{.example}
    ## `infix-lib.mapAttrsRecursiveCond'` usage example

    ```nix
    mapAttrsRecursiveCond'
      (attrs: !(attrs ? stop && attrs.stop))
      (path: value: nameValuePair "renamed-${last path}" value)
      {
        foo = {
          bar = "baz";
          stop = true;
        };
      }
    => {
      "renamed-foo" = {
        bar = "baz";
        stop = true;
      };
    }
    ```

    :::
  */
  mapAttrsRecursiveCond' =
    cond: f: attrs:
    let
      recurse =
        path:
        mapAttrs' (
          name: value:
          let
            pair = f (path ++ [ name ]) value;

            name' = pair.name;

            value' = pair.value;
          in
          if isAttrs value' && cond value' then
            nameValuePair name' (
              recurse (path ++ [ name' ]) value'
            )
          else
            nameValuePair name' value'
        );
    in
    recurse [ ] attrs;
}
