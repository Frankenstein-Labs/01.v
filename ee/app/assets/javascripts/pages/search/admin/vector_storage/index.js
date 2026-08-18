const adapterSelect = document.querySelector('.js-adapter-select');

if (adapterSelect) {
  const elasticsearchSection = document.querySelector('.js-elasticsearch-section');
  const opensearchSection = document.querySelector('.js-opensearch-section');
  const postgresqlSection = document.querySelector('.js-postgresql-section');

  const updateVisibility = (adapter) => {
    elasticsearchSection.classList.toggle('gl-hidden', adapter !== 'elasticsearch');
    opensearchSection.classList.toggle('gl-hidden', adapter !== 'opensearch');
    postgresqlSection.classList.toggle('gl-hidden', adapter !== 'postgresql');
  };

  updateVisibility(adapterSelect.value);
  adapterSelect.addEventListener('change', (e) => updateVisibility(e.currentTarget.value));
}
