import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import DependencyExportDropdown from 'ee/dependencies/components/dependency_export_dropdown.vue';
import createStore from 'ee/dependencies/store';
import {
  EXPORT_FORMAT_CSV,
  EXPORT_FORMAT_DEPENDENCY_LIST,
  EXPORT_FORMAT_JSON_ARRAY,
  EXPORT_FORMAT_CYCLONEDX_1_6_JSON,
  NAMESPACE_GROUP,
  NAMESPACE_PROJECT,
} from 'ee/dependencies/constants';

describe('DependencyExportDropdown component', () => {
  let store;
  let wrapper;

  const factory = ({ provide, props } = {}) => {
    store = createStore();
    jest.spyOn(store, 'dispatch').mockImplementation();

    wrapper = shallowMountExtended(DependencyExportDropdown, {
      store,
      provide,
      propsData: props,
    });
  };

  const findDisclosure = () => wrapper.findByTestId('export-disclosure');

  const dependencyListItem = {
    testId: 'dependency-list-item',
    exportType: EXPORT_FORMAT_DEPENDENCY_LIST,
  };
  const csvItem = {
    testId: 'csv-item',
    exportType: EXPORT_FORMAT_CSV,
  };
  const jsonArrayItem = {
    testId: 'json-array-item',
    exportType: EXPORT_FORMAT_JSON_ARRAY,
  };
  const cyclonedxItem = {
    testId: 'cyclonedx-1-6-item',
    exportType: EXPORT_FORMAT_CYCLONEDX_1_6_JSON,
  };

  const itHasCorrectLoadingLogic = (selector) => {
    it('shows export icon in default state', () => {
      const attributes = selector().attributes();
      expect(attributes).toHaveProperty('icon', 'export');
      expect(attributes).not.toHaveProperty('loading', true);
    });

    describe('when request is pending', () => {
      beforeEach(() => {
        store.state.fetchingInProgress = true;
      });

      it('shows loading spinner', () => {
        expect(selector().attributes()).toMatchObject({
          icon: '',
          loading: 'true',
        });
      });
    });
  };

  const itShowsDisclosureWithItems = (items) => {
    it('shows disclosure with expected items', () => {
      expect(findDisclosure().exists()).toBe(true);
      items.forEach((item) => {
        expect(wrapper.findByTestId(item.testId).exists()).toBe(true);
      });
    });

    it('dispatches export when item is clicked', () => {
      items.forEach((item) => {
        wrapper.findComponentByTestId(item.testId).vm.$emit('action');
        expect(store.dispatch).toHaveBeenCalledWith('fetchExport', {
          export_type: item.exportType,
        });
      });
    });
  };

  describe('when container is a project', () => {
    beforeEach(() => {
      factory({
        props: { container: NAMESPACE_PROJECT },
      });
    });

    itHasCorrectLoadingLogic(() => findDisclosure());
    itShowsDisclosureWithItems([dependencyListItem, csvItem, cyclonedxItem]);
  });

  describe('when container is a group', () => {
    beforeEach(() => {
      factory({ props: { container: NAMESPACE_GROUP } });
    });

    itHasCorrectLoadingLogic(() => findDisclosure());
    itShowsDisclosureWithItems([jsonArrayItem, csvItem]);
  });
});
