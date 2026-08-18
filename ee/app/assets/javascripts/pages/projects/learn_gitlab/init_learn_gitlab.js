import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import LearnGitlab from './components/learn_gitlab.vue';

export function initLearnGitlab() {
  const el = document.getElementById('js-learn-gitlab-app');

  if (!el) {
    return null;
  }

  const actions = convertObjectPropsToCamelCase(JSON.parse(el.dataset.actions));
  const sections = convertObjectPropsToCamelCase(JSON.parse(el.dataset.sections));
  const project = convertObjectPropsToCamelCase(JSON.parse(el.dataset.project));
  const { learnGitlabEndPath } = el.dataset;

  return initVueApp({
    el,
    name: 'LearnGitlabRoot',
    component: LearnGitlab,
    props: { actions, sections, project, learnGitlabEndPath },
  });
}
