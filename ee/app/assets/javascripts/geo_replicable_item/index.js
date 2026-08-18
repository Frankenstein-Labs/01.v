import VueApollo from 'vue-apollo';
import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import { getGraphqlClient } from 'ee/geo_shared/graphql/geo_client';
import GeoReplicableItemApp from './components/app.vue';

export const initGeoReplicableItem = () => {
  const el = document.getElementById('js-geo-replicable-item');
  const { replicableItemId, geoCurrentSiteId, geoTargetSiteId } = el.dataset;

  const replicableClass = convertObjectPropsToCamelCase(JSON.parse(el.dataset.replicableClassData));

  const apolloProvider = new VueApollo({
    defaultClient: getGraphqlClient(geoCurrentSiteId, geoTargetSiteId),
  });

  return initVueApp({
    el,
    name: 'GeoReplicableItemAppRoot',
    apolloProvider,
    component: GeoReplicableItemApp,
    props: {
      replicableItemId,
      replicableClass,
    },
  });
};
