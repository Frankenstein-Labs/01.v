import RefSelector from '~/vue_shared/components/ref/components/ref_selector.vue';
import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import { __ } from '~/locale';

export function initTargetBranchRefSwitcher() {
  const refSwitcherEl = document.getElementById('js-target-branch');

  if (!refSwitcherEl) {
    return null;
  }

  const { projectId } = refSwitcherEl.dataset;

  return initVueApp({
    el: refSwitcherEl,
    name: 'RefSelectorRoot',
    component: RefSelector,
    props: {
      projectId,
      value: '',
      useSymbolicRefNames: true,
      queryParams: { sort: 'updated_desc' },
      enabledRefTypes: ['REF_TYPE_BRANCHES'],
      translations: {
        noRefSelected: __('No branch selected'),
      },
    },
    events: {
      input(selectedRef) {
        document.getElementById('projects_target_branch_rule_target_branch').value =
          selectedRef.replace(/^refs\/(tags|heads)\//, '');
      },
    },
  });
}
