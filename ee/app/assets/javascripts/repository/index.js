import Vue from 'vue';
import initTree from '~/repository';
import repositoryPathMixin from '~/repository/mixins/repository_path';
import CodeOwners from '../vue_shared/components/code_owners/code_owners.vue';

const initCodeOwnersApp = (router, apolloProvider, projectPath) => {
  const codeOwnersEl = document.querySelector('#js-code-owners');
  if (!codeOwnersEl) return null;

  const { branch, canViewBranchRules, branchRulesPath } = codeOwnersEl.dataset;
  return new Vue({
    el: codeOwnersEl,
    name: 'RepositoryCodeOwnersRoot',
    router,
    apolloProvider,
    mixins: [repositoryPathMixin],
    computed: {
      currentPath() {
        return this.computedPath;
      },
    },
    render(h) {
      return h(CodeOwners, {
        props: {
          filePath: this.computedPath,
          projectPath,
          branch,
          canViewBranchRules,
          branchRulesPath,
        },
      });
    },
  });
};

export default () => {
  const { router, apolloProvider, projectPath } = initTree();

  initCodeOwnersApp(router, apolloProvider, projectPath);
};
