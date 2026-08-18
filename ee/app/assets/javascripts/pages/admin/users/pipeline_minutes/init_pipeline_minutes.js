import { GlToast } from '@gitlab/ui';
import Vue from 'vue';
import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import { CONTEXT_TYPE } from '~/members/constants';
import ResetButton from './reset_button.vue';

Vue.use(GlToast);

export function initPipelineMinutes() {
  const el = document.getElementById('js-pipeline-minutes-vue');

  if (el) {
    const { resetMinutesPath, contextType } = el.dataset;

    initVueApp({
      el,
      name: 'ResetButtonRoot',
      provide: {
        resetMinutesPath,
        contextType: contextType || CONTEXT_TYPE.GROUP,
      },
      component: ResetButton,
    });
  }
}
