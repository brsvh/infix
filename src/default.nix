{
  infix,
  ...
}:
{
  flake = {
    overlays = {
      default =
        final: prev:
        import infix.overlays.default final prev;

      emacs-packages =
        final: prev:
        import infix.overlays.emacsPackages final prev;
    };
  };
}
