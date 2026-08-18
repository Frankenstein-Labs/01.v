import { shallowMount } from '@vue/test-utils';
import models from 'test_fixtures/api/admin/data_management/snippet_repositories.json';
import DataManagementItem from 'ee/admin/data_management/components/data_management_item.vue';
import GeoListItem from 'ee/geo_shared/list/components/geo_list_item.vue';
import { MOCK_MODEL_TYPES } from 'ee_jest/admin/data_management/mock_data';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import { createAlert } from '~/alert';
import { putModelAction } from 'ee/api/data_management_api';
import showToast from '~/vue_shared/plugins/global_toast';
import waitForPromises from 'helpers/wait_for_promises';
import { VERIFICATION_STATUS_STATES } from 'ee/geo_shared/constants';
import { joinPaths } from '~/lib/utils/url_utility';

jest.mock('~/alert');
jest.mock('ee/api/data_management_api');
jest.mock('~/vue_shared/plugins/global_toast');

describe('DataManagementItem', () => {
  let wrapper;

  const [rawModel] = models;
  const model = convertObjectPropsToCamelCase(rawModel, { deep: true });
  const modelDisplayName = `${MOCK_MODEL_TYPES[0].modelClass}/${model.recordIdentifier}`;
  const basePath = 'admin/data_management';

  const checksumAction = {
    id: 'geo-checksum-item',
    value: 'checksum',
    text: 'Checksum',
    loading: false,
    successMessage: `Successfully recalculated checksum for ${modelDisplayName}.`,
    errorMessage: `There was an error recalculating checksum for ${modelDisplayName}.`,
  };

  const createComponent = (props = {}) => {
    wrapper = shallowMount(DataManagementItem, {
      provide: {
        basePath,
      },
      propsData: {
        activeModelType: MOCK_MODEL_TYPES[0],
        initialItem: model,
        ...props,
      },
    });
  };

  const findGeoListItem = () => wrapper.findComponent(GeoListItem);
  const fireActionClicked = (action) => findGeoListItem().vm.$emit('action-clicked', action);

  describe('when checksumEnabled is true', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders GeoListItem with correct props', () => {
      expect(findGeoListItem().props()).toMatchObject({
        name: modelDisplayName,
        detailsPath: joinPaths(
          basePath,
          MOCK_MODEL_TYPES[0].namePlural,
          model.recordIdentifier.toString(),
        ),
        timeAgoArray: [
          {
            label: 'Created',
            dateString: model.createdAt,
            defaultText: 'Unknown',
          },
          {
            label: 'Last checksum',
            dateString: model.checksumInformation.lastChecksum,
            defaultText: 'Unknown',
          },
        ],
        actionsArray: [checksumAction],
        errorsArray: [],
      });
    });
  });

  describe('when checksumEnabled is false', () => {
    beforeEach(() => {
      createComponent({ activeModelType: { ...MOCK_MODEL_TYPES[0], checksumEnabled: false } });
    });

    it('renders GeoListItem with correct props', () => {
      expect(findGeoListItem().props()).toMatchObject({
        name: modelDisplayName,
        detailsPath: joinPaths(
          basePath,
          MOCK_MODEL_TYPES[0].namePlural,
          model.recordIdentifier.toString(),
        ),
        timeAgoArray: [
          {
            label: 'Created',
            dateString: model.createdAt,
            defaultText: 'Unknown',
          },
        ],
        actionsArray: [],
        errorsArray: [],
      });
    });
  });

  describe('when model has checksum failure', () => {
    const modelWithFailure = {
      ...model,
      checksumInformation: {
        ...model.checksumInformation,
        checksumState: 'failed',
        checksumFailure: 'Something went wrong',
      },
    };

    it('passes errors array to GeoListItem', () => {
      createComponent({ initialItem: modelWithFailure });

      expect(findGeoListItem().props('errorsArray')).toStrictEqual([
        {
          label: 'Verification failure',
          message: 'Something went wrong',
        },
      ]);
    });
  });

  describe('when GeoListItem emits checksumAction clicked event', () => {
    beforeEach(() => {
      createComponent();
    });

    it('starts loading state', async () => {
      await fireActionClicked(checksumAction);

      expect(findGeoListItem().props('actionsArray')[0].loading).toBe(true);
    });

    it('calls putModelAction', () => {
      fireActionClicked(checksumAction);

      expect(putModelAction).toHaveBeenCalledWith(
        MOCK_MODEL_TYPES[0].namePlural,
        model.recordIdentifier,
        checksumAction.value,
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

        fireActionClicked(checksumAction);
        await waitForPromises();
      });

      it('updates item', () => {
        const lastChecksum = findGeoListItem()
          .props('timeAgoArray')
          .find((timeAgo) => timeAgo.label === 'Last checksum').dateString;

        expect(lastChecksum).toBe(updatedModel.checksum_information.last_checksum);
      });

      it('stops loading state', () => {
        expect(findGeoListItem().props('actionsArray')[0].loading).toBe(false);
      });

      it('shows toast', () => {
        expect(showToast).toHaveBeenCalledWith(checksumAction.successMessage);
      });

      it('does not create alert', () => {
        expect(createAlert).not.toHaveBeenCalled();
      });
    });

    describe('when action fails', () => {
      const error = new Error('Failed to load models');

      beforeEach(async () => {
        putModelAction.mockRejectedValue(error);

        fireActionClicked(checksumAction);
        await waitForPromises();
      });

      it('creates alert', () => {
        expect(createAlert).toHaveBeenCalledWith({
          message: checksumAction.errorMessage,
          captureError: true,
          error,
        });
      });

      it('stops loading state', () => {
        expect(findGeoListItem().props('actionsArray')[0].loading).toBe(false);
      });
    });
  });

  describe.each`
    checksumState  | expectedStatus                          | expectedLabel
    ${'pending'}   | ${VERIFICATION_STATUS_STATES.PENDING}   | ${'Verification pending'}
    ${'started'}   | ${VERIFICATION_STATUS_STATES.STARTED}   | ${'Verifying'}
    ${'succeeded'} | ${VERIFICATION_STATUS_STATES.SUCCEEDED} | ${'Verified'}
    ${'failed'}    | ${VERIFICATION_STATUS_STATES.FAILED}    | ${'Verification failed'}
    ${'disabled'}  | ${VERIFICATION_STATUS_STATES.DISABLED}  | ${'Verification disabled'}
    ${undefined}   | ${VERIFICATION_STATUS_STATES.UNKNOWN}   | ${'Verification unknown'}
  `('when checkSum state is $checksumState', ({ checksumState, expectedStatus, expectedLabel }) => {
    it('passes correct status props to GeoListItem', () => {
      createComponent({
        initialItem: {
          ...model,
          checksumInformation: { ...model.checksumInformation, checksumState },
        },
      });

      expect(findGeoListItem().props('statusArray')).toEqual([
        {
          tooltip: `Checksum: ${expectedStatus.title}`,
          icon: expectedStatus.icon,
          variant: expectedStatus.variant,
          label: expectedLabel,
        },
      ]);
    });
  });

  describe('when fileSize is provided', () => {
    it('renders size', () => {
      createComponent({ initialItem: { ...model, fileSize: 1024 } });

      expect(findGeoListItem().text()).toContain('Storage: 1.00 KiB');
    });
  });

  describe('when fileSize is 0', () => {
    it('renders size"', () => {
      createComponent({ initialItem: { ...model, fileSize: 0 } });

      expect(findGeoListItem().text()).toContain('Storage: 0 B');
    });
  });

  describe('when fileSize is not provided', () => {
    it('renders size as "Unknown"', () => {
      createComponent({ initialItem: { ...model, fileSize: null } });

      expect(findGeoListItem().text()).toContain('Storage: Unknown');
    });
  });
});
