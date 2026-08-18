export const updateDocumentTitle = (initialTitle = document.title) => {
  return function updateTitle(to) {
    const title = to.matched.reduce((prev, curr) => {
      if (curr.meta.text) {
        return `${curr.meta.text} · ${prev}`;
      }
      return prev;
    }, initialTitle);

    document.title = title;
  };
};
