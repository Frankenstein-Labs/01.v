import { GlTableLite, GlSkeletonLoader } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import BaseFeatureSettingsTable from 'ee/ai/shared/feature_settings/base_feature_settings_table.vue';
import { featureSettings } from './mock_data';

const MOCK_FIELDS = [
  {
    key: 'sub_feature',
    label: 'Features',
    loaderWidths: ['200', '80', '150'],
  },
  {
    key: 'model_name',
    label: 'Models',
  },
];

describe('BaseFeatureSettingsTable', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = mountExtended(BaseFeatureSettingsTable, {
      propsData: {
        items: featureSettings,
        isLoading: false,
        fields: MOCK_FIELDS,
        ...props,
      },
      scopedSlots: {
        'head(sub_feature)': '<div>Sub feature</div>',
        'head(model_name)': '<div>Model name</div>',
        'cell(sub_feature)': '<div>Sub feature content</div>',
        'cell(model_name)': '<div>Model name content</div>',
      },
    });
  };

  const findTable = () => wrapper.findComponent(GlTableLite);
  const findTableRowCells = (idx) => findTable().find('tbody').findAll('tr').at(idx).findAll('td');
  const findTableHeaderCells = (idx) =>
    findTable().find('thead').findAll('tr').at(idx).findAll('th');

  it('renders table component', () => {
    createComponent();

    expect(findTable().exists()).toBe(true);
  });

  describe('when loading', () => {
    beforeEach(() => {
      createComponent({ isLoading: true });
    });

    it('renders loader when `loaderWidths` is provided for that field', () => {
      const withLoader = findTableRowCells(0).at(0);
      expect(withLoader.findComponent(GlSkeletonLoader).exists()).toBe(true);
    });

    it('does not render loader if no `loaderWidths` provided for that field', () => {
      const withoutLoader = findTableRowCells(0).at(1);
      expect(withoutLoader.findComponent(GlSkeletonLoader).exists()).toBe(false);
    });

    it('does not render loaders in header', () => {
      const headers = findTableHeaderCells(0);
      headers.wrappers.forEach((header) =>
        expect(header.findComponent(GlSkeletonLoader).exists()).toBe(false),
      );
    });

    it('does not render content', () => {
      const rowCells = findTableRowCells(0);
      expect(rowCells.at(0).text()).not.toContain('Sub feature content');
      expect(rowCells.at(1).text()).not.toContain('Model name content');
    });
  });

  describe('when not loading', () => {
    beforeEach(() => {
      createComponent();
    });

    it('does not render loaders', () => {
      const rowCells = findTableRowCells(0);
      rowCells.wrappers.forEach((cell) =>
        expect(cell.findComponent(GlSkeletonLoader).exists()).toBe(false),
      );
    });

    it('renders content', () => {
      const rowCells = findTableRowCells(0);
      expect(rowCells.at(0).text()).toContain('Sub feature content');
      expect(rowCells.at(1).text()).toContain('Model name content');
    });
  });
});
