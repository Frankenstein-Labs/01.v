import Vue from 'vue';
import VueApollo from 'vue-apollo';
import VueRouter from 'vue-router';
import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import initBlobShow from '~/blob/show/show_blob_bundle';
import createDefaultClient from '~/lib/graphql';
import CodeOwners from 'ee/vue_shared/components/code_owners/code_owners.vue';

export function initEEBlobShow() {
  initBlobShow();

  Vue.use(VueApollo);
  Vue.use(VueRouter);

  const apolloProvider = new VueApollo({
    defaultClient: createDefaultClient(),
  });

  const router = new VueRouter({ mode: 'history' });
  const codeOwnersEl = document.querySelector('#js-code-owners');

  if (codeOwnersEl) {
    const { blobPath, projectPath, branch, canViewBranchRules, branchRulesPath } =
      codeOwnersEl.dataset;

    initVueApp({
      el: document.getElementById('js-code-owners'),
      name: 'CodeOwnersRoot',
      apolloProvider,
      router,
      component: CodeOwners,
      props: {
        filePath: blobPath,
        projectPath,
        branch,
        canViewBranchRules,
        branchRulesPath,
      },
    });
  }
}
