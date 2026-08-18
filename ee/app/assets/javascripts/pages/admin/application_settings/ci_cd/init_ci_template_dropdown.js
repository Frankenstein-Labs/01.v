import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import CiTemplateDropdown from './ci_template_dropdown.vue';

export function initCiTemplateDropdown() {
  const el = document.querySelector('.js-ci-template-dropdown');

  if (!el) {
    return null;
  }

  const { gitlabCiYmls, value } = el.dataset;

  return initVueApp({
    el,
    name: 'CiTemplateDropdownRoot',
    provide: {
      gitlabCiYmls: JSON.parse(gitlabCiYmls),
      initialSelectedGitlabCiYmlName: value,
    },
    component: CiTemplateDropdown,
  });
}
