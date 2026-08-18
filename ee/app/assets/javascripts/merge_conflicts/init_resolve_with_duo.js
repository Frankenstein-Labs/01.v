import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { defaultClient } from '~/graphql_shared/issuable_client';
import ResolveWithDuoButton from 'ee/merge_conflicts/components/resolve_with_duo_button.vue';

Vue.use(VueApollo);

const apolloProvider = new VueApollo({
  defaultClient,
});

export function initResolveWithDuo() {
  const el = document.querySelector('.js-resolve-with-duo');

  if (!el) return;

  const mr = { ...el.dataset };

  // eslint-disable-next-line no-new
  new Vue({
    el,
    name: 'ResolveWithDuoButtonApp',
    apolloProvider,
    render(h) {
      return h(ResolveWithDuoButton, {
        class: 'gl-hidden @sm/panel:gl-inline-flex gl-self-start',
        props: { mr },
      });
    },
  });
}
