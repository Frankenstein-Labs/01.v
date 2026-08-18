import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import { s__ } from '~/locale';
import { createAlert } from '~/alert';
import { parseBoolean, convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import { defaultClient } from '~/analytics/shared/graphql/client';
import { capitalizeFirstCharacter } from '~/lib/utils/text_utility';
import VSASettingsApp from './components/app.vue';

Vue.use(VueApollo);

export default () => {
  const el = document.getElementById('js-vsa-settings-app');
  if (!el) return false;

  const {
    vsaPath,
    fullPath,
    isProject,
    groupPath,
    defaultStages: rawDefaultStages,
    stageEvents: rawStageEvents,
    valueStreamGid,
  } = el.dataset;

  let stageEvents = [];
  try {
    stageEvents = JSON.parse(rawStageEvents).map((ev) =>
      convertObjectPropsToCamelCase(ev, { deep: true }),
    );
  } catch (e) {
    createAlert({
      message: s__('CycleAnalytics|Failed to parse stage events.'),
    });
    return false;
  }

  let defaultStages = [];
  if (rawDefaultStages) {
    try {
      defaultStages = JSON.parse(rawDefaultStages).map(({ name, ...rest }) => ({
        ...convertObjectPropsToCamelCase(rest),
        name: capitalizeFirstCharacter(name),
      }));
    } catch (e) {
      createAlert({
        message: s__('CycleAnalytics|Failed to parse default stages.'),
      });
      return false;
    }
  }

  const apolloProvider = new VueApollo({ defaultClient });

  return initVueApp({
    el,
    name: 'VSASettingsAppRoot',
    apolloProvider,
    provide: {
      vsaPath,
      fullPath,
      isProject: parseBoolean(isProject),
      groupPath,
      stageEvents,
      valueStreamGid,
      defaultStages,
    },
    component: VSASettingsApp,
  });
};
