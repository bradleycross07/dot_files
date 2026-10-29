(function noMiddlePaste() {
  document.addEventListener("mouseup", (e) => {
    if (e.button === 1) e.preventDefault();
  }, true);
})();
