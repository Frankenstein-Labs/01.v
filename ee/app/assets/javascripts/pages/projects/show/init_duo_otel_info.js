import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import DuoOtelInfo from './components/duo_otel_info.vue';

export function initDuoOtelInfo() {
  const el = document.getElementById('js-duo-otel-info');

  if (!el) {
    return null;
  }

  const { createWorkflowPath } = el.dataset;

  return initVueApp({
    el,
    name: 'DuoOtelInfoRoot',
    component: DuoOtelInfo,
    props: {
      createWorkflowPath,
    },
  });
}
