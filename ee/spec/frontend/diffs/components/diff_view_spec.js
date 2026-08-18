import { mount } from '@vue/test-utils';
import Vue from 'vue';
import { createTestingPinia } from '@pinia/testing';
import { PiniaVuePlugin } from 'pinia';
import { getDiffFileMock } from 'jest/diffs/mock_data/diff_file';
import DiffViewComponent from '~/diffs/components/diff_view.vue';
import { globalAccessorPlugin } from '~/pinia/plugins';
import { useLegacyDiffs } from '~/diffs/stores/legacy_diffs';

Vue.use(PiniaVuePlugin);

describe('EE DiffView', () => {
  let wrapper;
  let pinia;

  function createComponent({ withCodequality = true, provide = {} }) {
    let codequalityData = null;

    if (withCodequality) {
      codequalityData = {
        files: {
          [useLegacyDiffs().diffFiles[0].file_path]: [
            { line: 1, description: 'Unexpected alert.', severity: 'minor' },
            {
              line: 3,
              description: 'Arrow function has too many statements (52). Maximum allowed is 30.',
              severity: 'minor',
            },
          ],
        },
      };
    }

    wrapper = mount(DiffViewComponent, {
      pinia,
      propsData: {
        diffFile: useLegacyDiffs().diffFiles[0],
        diffLines: [],
        codequalityData,
      },
      provide,
    });
  }

  beforeEach(() => {
    pinia = createTestingPinia({ plugins: [globalAccessorPlugin] });
    useLegacyDiffs().diffFiles = [getDiffFileMock()];
  });

  describe('when there is diff data for the file', () => {
    beforeEach(() => {
      createComponent({
        withCodequality: true,
      });
    });

    it('has the with-inline-findings class', () => {
      expect(wrapper.classes('with-inline-findings')).toBe(true);
    });
  });

  describe('when there is no diff data for the file', () => {
    beforeEach(() => {
      createComponent({ withCodequality: false });
    });

    it('does not have the with-inline-findings class', () => {
      expect(wrapper.classes('with-inline-findings')).toBe(false);
    });
  });
});
