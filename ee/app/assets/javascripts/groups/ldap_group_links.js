export default () => {
  const showGroupLink = () => {
    const cnLink = document.querySelector('.cn-link');
    const filterLink = document.querySelector('.filter-link');
    if (!cnLink || !filterLink) return;

    const checkedSync =
      document.querySelector('input[name="sync_method"]:checked')?.value === 'group';

    cnLink.classList.toggle('!gl-hidden', !checkedSync);
    filterLink.classList.toggle('!gl-hidden', checkedSync);
  };

  document
    .querySelectorAll('input[name="sync_method"]')
    .forEach((el) => el.addEventListener('change', showGroupLink));
  showGroupLink();
};
