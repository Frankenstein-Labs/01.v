import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';
import { __ } from '~/locale';

const parseProvideData = (el) => {
  const { fullPath } = el.dataset;
  return {
    fullPath,
  };
};

export const getTransferTabMetadata = ({ vueComponent, includeEl = false } = {}) => {
  const el = document.querySelector('#js-transfer-usage-app');
  if (!el) return false;

  const apolloProvider = new VueApollo({
    defaultClient: createDefaultClient(),
  });

  const transferTabMetadata = {
    title: __('Transfer'),
    hash: '#transfer-quota-tab',
    testid: 'transfer-tab',
    featureCategory: 'consumables_cost_management',
    component: {
      name: 'TransferTab',
      apolloProvider,
      provide: parseProvideData(el),
      render(createElement) {
        return createElement(vueComponent);
      },
    },
  };
  if (includeEl) {
    transferTabMetadata.component.el = el;
  }

  return transferTabMetadata;
};
