import { parseBoolean, convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_SECURITY_PROJECT_TRACKED_CONTEXT } from 'ee/graphql_shared/constants';
import DependenciesApp from './components/app.vue';
import createStore from './store';
import apolloProvider from './graphql/provider';
import { NAMESPACE_GROUP, NAMESPACE_PROJECT } from './constants';

export default (namespaceType) => {
  const el = document.querySelector('#js-dependencies-app');

  const {
    hasDependencies,
    emptyStateSvgPath,
    documentationPath,
    endpoint,
    exportEndpoint,
    sbomReportsErrors,
    latestSuccessfulScanPath,
    scanFinishedAt,
    groupFullPath,
    projectFullPath,
  } = el.dataset;

  const store = createStore();

  const provide = {
    hasDependencies: parseBoolean(hasDependencies),
    emptyStateSvgPath,
    documentationPath,
    endpoint,
    exportEndpoint,
    namespaceType,
    latestSuccessfulScanPath,
    scanFinishedAt,
    groupFullPath,
    projectFullPath,
    fullPath: '',
  };

  if (namespaceType === NAMESPACE_GROUP) {
    provide.fullPath = groupFullPath;
  }

  if (namespaceType === NAMESPACE_PROJECT) {
    provide.fullPath = projectFullPath;

    const { defaultBranchContext } = el.dataset;

    if (defaultBranchContext) {
      const parsed = convertObjectPropsToCamelCase(JSON.parse(defaultBranchContext));
      provide.defaultBranchContext = {
        ...parsed,
        id: convertToGraphQLId(TYPENAME_SECURITY_PROJECT_TRACKED_CONTEXT, parsed.id),
      };
    }
  }

  const props = {
    sbomReportsErrors: sbomReportsErrors ? JSON.parse(sbomReportsErrors) : [],
  };

  return initVueApp({
    el,
    name: 'DependenciesAppRoot',
    component: DependenciesApp,
    store,
    apolloProvider,
    provide,
    props,
  });
};
