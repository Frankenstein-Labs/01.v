import {
  initNamespacesIndexingRestrictions,
  initProjectsIndexingRestrictions,
} from 'ee/admin/application_settings/search/init_indexing_restrictions';

const onLimitCheckboxChange = (checked, limitByNamespaces, limitByProjects) => {
  limitByNamespaces?.classList.toggle('hidden', !checked);
  limitByProjects?.classList.toggle('hidden', !checked);
};

// ElasticSearch
const container = document.querySelector('#js-elasticsearch-settings');

if (container) {
  container.querySelectorAll('.js-limit-checkbox').forEach((checkbox) => {
    checkbox.addEventListener('change', (e) =>
      onLimitCheckboxChange(
        e.currentTarget.checked,
        container.querySelector('.js-limit-namespaces'),
        container.querySelector('.js-limit-projects'),
      ),
    );
  });
}

initNamespacesIndexingRestrictions();
initProjectsIndexingRestrictions();
