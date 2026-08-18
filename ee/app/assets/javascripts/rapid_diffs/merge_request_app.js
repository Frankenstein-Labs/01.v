import Vue, { ref } from 'vue';
import createDefaultClient from '~/lib/graphql';
import { createAlert } from '~/alert';
import { __ } from '~/locale';
import { pinia } from '~/pinia/instance';
import { adapters } from '~/rapid_diffs/app/adapter_configs/merge_request';
import { MergeRequestRapidDiffsApp } from '~/rapid_diffs/merge_request_app';
import { useCodeQuality } from '~/rapid_diffs/stores/code_quality';
import { useFindingsDrawer } from '~/mr_notes/store/findings_drawer';
import { createLineInlineFindingsAdapter } from 'ee/rapid_diffs/adapters/line_inline_findings';
import getMrSastReport from 'ee/rapid_diffs/graphql/get_mr_sast_report.query.graphql';
import FindingsDrawer from 'ee/diffs/components/shared/findings_drawer.vue';

class MergeRequestRapidDiffsAppEE extends MergeRequestRapidDiffsApp {
  #sastFindings = ref(null);

  adapterConfig = {
    ...adapters,
    text_inline: [
      ...adapters.text_inline,
      createLineInlineFindingsAdapter({ sastFindings: this.#sastFindings }),
    ],
    text_parallel: [
      ...adapters.text_parallel,
      createLineInlineFindingsAdapter({ sastFindings: this.#sastFindings }),
    ],
  };

  async init() {
    const appInitialized = super.init();
    this.#initCodeQuality();
    this.#initSast();
    this.#initFindingsDrawer();
    await appInitialized;
  }

  #initCodeQuality() {
    const { codequalityEndpoint } = this.appData;
    if (!codequalityEndpoint) return;

    const store = useCodeQuality(pinia);
    store.endpoint = codequalityEndpoint;
    store.fetchCodeQuality();
  }

  async #initSast() {
    const { sastReportAvailable, projectPath, iid } = this.appData;
    if (!sastReportAvailable) return;

    try {
      const { data } = await createDefaultClient().query({
        query: getMrSastReport,
        variables: { fullPath: projectPath, iid: `${iid}` },
      });
      this.#sastFindings.value = data?.project?.mergeRequest?.sastReport?.report ?? null;
    } catch (error) {
      createAlert({
        message: __('Failed to load SAST findings. Try reloading the page.'),
        captureError: true,
        error,
      });
    }
  }

  #initFindingsDrawer() {
    const { codequalityEndpoint, sastReportAvailable, projectPath, projectName } = this.appData;
    if (!codequalityEndpoint && !sastReportAvailable) return;

    const store = useCodeQuality(pinia);
    const drawerStore = useFindingsDrawer(pinia);
    const sastFindings = this.#sastFindings;
    // eslint-disable-next-line no-new
    new Vue({
      el: this.root.appendChild(document.createElement('div')),
      pinia,
      name: 'FindingsDrawerRoot',
      render: (h) =>
        store.hasFindings || sastFindings.value?.added?.length
          ? h(FindingsDrawer, {
              props: {
                drawer: drawerStore.activeDrawer,
                project: { fullPath: projectPath, nameWithNamespace: projectName },
              },
              on: { close: () => drawerStore.setDrawer({}) },
            })
          : null,
    });
  }
}

export const createMergeRequestRapidDiffsApp = (options) => {
  return new MergeRequestRapidDiffsAppEE(options);
};
