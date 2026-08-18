import { shallowMount } from '@vue/test-utils';
import { GlLoadingIcon } from '@gitlab/ui';
import { nextTick } from 'vue';
import models from 'test_fixtures/api/admin/data_management/snippet_repositories.json';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import AdminDataManagementItemApp from 'ee/admin/data_management_item/components/app.vue';
import ChecksumInfo from 'ee/admin/data_management_item/components/checksum_info.vue';
import ModelInfo from 'ee/admin/data_management_item/components/model_info.vue';
import { getModel, putModelAction } from 'ee/api/data_management_api';
import { MOCK_MODEL_TYPES } from 'ee_jest/admin/data_management/mock_data';
import waitForPromises from 'helpers/wait_for_promises';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import { createAlert } from '~/alert';
import showToast from '~/vue_shared/plugins/global_toast';

jest.mock('~/alert');
jest.mock('ee/api/data_management_api');
jest.mock('~/vue_shared/plugins/global_toast');

describe('AdminDataManagementItemApp', () => {
  let wrapper;

  const [rawModel] = models;
  const model = convertObjectPropsToCamelCase(rawModel, { deep: true });
  const modelDisplayName = `${MOCK_MODEL_TYPES[0].modelClass}/${model.recordIdentifier}`;

  const defaultProps = {
    modelTypeData: MOCK_MODEL_TYPES[0],
    modelId: model.recordIdentifier.toString(),
  };

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMount(AdminDataManagementItemApp, {
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  const findPageHeading = () => wrapper.findComponent(PageHeading);
  const findGlLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findChecksumInfo = () => wrapper.findComponent(ChecksumInfo);
  const findModelInfo = () => wrapper.findComponent(ModelInfo);

  it('renders page heading', () => {
    createComponent();

    expect(findPageHeading().props('heading')).toBe(modelDisplayName);
  });

  it('renders loading icon', () => {
    createComponent();

    expect(findGlLoadingIcon().exists()).toBe(true);
  });

  it('loads model', () => {
    createComponent();

    expect(getModel).toHaveBeenCalledWith(MOCK_MODEL_TYPES[0].namePlural, defaultProps.modelId);
  });

  describe('when loading model succeeds and checksumEnabled is true', () => {
    beforeEach(async () => {
      getModel.mockResolvedValue({ data: model });
      createComponent();
      await waitForPromises();
    });

    it('renders model info', () => {
      expect(findModelInfo().props('model')).toEqual(model);
    });

    it('renders checksum info', () => {
      expect(findChecksumInfo().props()).toMatchObject({
        details: model.checksumInformation,
        checksumLoading: false,
      });
    });

    it('does not create alert', () => {
      expect(createAlert).not.toHaveBeenCalled();
    });

    it('hides loading icon', () => {
      expect(findGlLoadingIcon().exists()).toBe(false);
    });

    describe('when model has no checksumInformation', () => {
      beforeEach(async () => {
        getModel.mockResolvedValue({ data: { ...model, checksumInformation: null } });
        createComponent();
        await waitForPromises();
      });

      it('passes empty object to ChecksumInfo', () => {
        expect(findChecksumInfo().props('details')).toEqual({});
      });
    });
  });

  describe('when loading model succeeds and checksumEnabled is false', () => {
    beforeEach(async () => {
      getModel.mockResolvedValue({ data: model });
      createComponent({
        props: { modelTypeData: { ...MOCK_MODEL_TYPES[0], checksumEnabled: false } },
      });
      await waitForPromises();
    });

    it('renders model info', () => {
      expect(findModelInfo().props('model')).toEqual(model);
    });

    it('does not render checksum info', () => {
      expect(findChecksumInfo().exists()).toBe(false);
    });

    it('does not create alert', () => {
      expect(createAlert).not.toHaveBeenCalled();
    });

    it('hides loading icon', () => {
      expect(findGlLoadingIcon().exists()).toBe(false);
    });
  });

  describe('when loading model failed', () => {
    const error = new Error('Failed to load models');

    beforeEach(async () => {
      getModel.mockRejectedValue(error);
      createComponent();
      await waitForPromises();
    });

    it('creates alert', () => {
      const message = `There was an error fetching ${modelDisplayName}. Please refresh the page and try again.`;
      expect(createAlert).toHaveBeenCalledWith({ message, captureError: true, error });
    });

    it('hides loading icon', () => {
      expect(findGlLoadingIcon().exists()).toBe(false);
    });

    it('does not render model details', () => {
      expect(findModelInfo().exists()).toBe(false);
    });

    it('does not render checksum info', () => {
      expect(findChecksumInfo().exists()).toBe(false);
    });
  });

  describe('when checksumInfo emits `recalculate-checksum` event', () => {
    beforeEach(async () => {
      getModel.mockResolvedValue({ data: model });

      createComponent();
      await waitForPromises();
    });

    it('starts loading state', async () => {
      findChecksumInfo().vm.$emit('recalculate-checksum');
      await nextTick();

      expect(findChecksumInfo().props('checksumLoading')).toBe(true);
    });

    it('calls putModelAction', () => {
      findChecksumInfo().vm.$emit('recalculate-checksum');

      expect(putModelAction).toHaveBeenCalledWith(
        MOCK_MODEL_TYPES[0].namePlural,
        model.recordIdentifier.toString(),
        'checksum',
      );
    });

    describe('when action succeeds', () => {
      const updatedModel = {
        ...rawModel,
        checksum_information: {
          ...rawModel.checksum_information,
          last_checksum: '2025-10-28T07:40:22.061Z',
        },
      };

      beforeEach(async () => {
        putModelAction.mockResolvedValue({ data: updatedModel });

        findChecksumInfo().vm.$emit('recalculate-checksum');
        await waitForPromises();
      });

      it('updates checksumInfo details', () => {
        const updatedDetails = convertObjectPropsToCamelCase(updatedModel.checksum_information, {
          deep: true,
        });

        expect(findChecksumInfo().props('details')).toStrictEqual(updatedDetails);
      });

      it('stops loading state', () => {
        expect(findChecksumInfo().props('checksumLoading')).toBe(false);
      });

      it('shows toast', () => {
        expect(showToast).toHaveBeenCalledWith(
          `Successfully recalculated checksum for ${modelDisplayName}.`,
        );
      });

      it('does not create alert', () => {
        expect(createAlert).not.toHaveBeenCalled();
      });
    });

    describe('when action fails', () => {
      const error = new Error('Failed to calculate checksum');

      beforeEach(async () => {
        putModelAction.mockRejectedValue(error);

        findChecksumInfo().vm.$emit('recalculate-checksum');
        await waitForPromises();
        await nextTick();
      });

      it('stops loading state', () => {
        expect(findChecksumInfo().props('checksumLoading')).toBe(false);
      });

      it('creates alert', () => {
        expect(createAlert).toHaveBeenCalledWith({
          message: `There was an error recalculating checksum for ${modelDisplayName}.`,
          captureError: true,
          error,
        });
      });
    });
  });
});
