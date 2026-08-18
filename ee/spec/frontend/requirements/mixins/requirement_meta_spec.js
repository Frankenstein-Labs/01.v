import { shallowMount } from '@vue/test-utils';

import { nextTick } from 'vue';
import RequirementItem from 'ee/requirements/components/requirement_item.vue';
import { filterState } from 'ee/requirements/constants';
import {
  mockAuthor,
  mockTestReport,
  requirement1 as mockRequirement,
  requirement4 as mockRequirementWithInvalidDate,
} from '../mock_data';

const createComponent = (requirement = mockRequirement) =>
  shallowMount(RequirementItem, {
    propsData: {
      requirement,
    },
  });

describe('RequirementMeta Mixin', () => {
  let wrapper;

  beforeEach(() => {
    wrapper = createComponent();
  });

  describe('computed', () => {
    describe('titleHtml', () => {
      it('returns value of `requirement.titleHtml`', () => {
        expect(wrapper.vm.titleHtml).toBe(mockRequirement.titleHtml);
      });
    });

    describe('descriptionHtml', () => {
      it('returns value of `requirement.descriptionHtml`', () => {
        expect(wrapper.vm.descriptionHtml).toBe(mockRequirement.descriptionHtml);
      });
    });

    describe('isArchived', () => {
      it('returns true when `requirement.state` is "ARCHIVED"', async () => {
        wrapper.setProps({
          requirement: {
            ...mockRequirement,
            state: filterState.archived,
          },
        });

        await nextTick();

        expect(wrapper.vm.isArchived).toBe(true);
      });

      it('returns false when `requirement.state` is "OPENED"', () => {
        expect(wrapper.vm.isArchived).toBe(false);
      });
    });

    describe('author', () => {
      it('returns value of `requirement.author`', () => {
        expect(wrapper.vm.author).toStrictEqual(mockAuthor);
      });
    });

    describe('createdAtFormatted', () => {
      it('returns empty string if createdAt is null or undefined', () => {
        wrapper = createComponent(mockRequirementWithInvalidDate);

        expect(wrapper.vm.createdAtFormatted).toBe('');
      });

      it('returns timeago-style string representing `requirement.createdAtFormatted`', () => {
        // We don't have to be accurate here as it is already covered in rspecs
        expect(wrapper.vm.createdAtFormatted).toContain('created');
        expect(wrapper.vm.createdAtFormatted).toContain('ago');
      });
    });

    describe('updatedAtFormatted', () => {
      it('returns empty string if updatedAt is null or undefined', () => {
        wrapper = createComponent(mockRequirementWithInvalidDate);

        expect(wrapper.vm.updatedAtFormatted).toBe('');
      });

      it('returns timeago-style string representing `requirement.updatedAtFormatted`', () => {
        // We don't have to be accurate here as it is already covered in rspecs
        expect(wrapper.vm.updatedAtFormatted).toContain('updated');
        expect(wrapper.vm.updatedAtFormatted).toContain('ago');
      });
    });

    describe('testReport', () => {
      it('returns testReport object from reports array within `requirement`', () => {
        expect(wrapper.vm.testReport).toStrictEqual(mockTestReport);
      });
    });

    describe('canUpdate', () => {
      it('returns value of `requirement.userPermissions.updateRequirement`', () => {
        expect(wrapper.vm.canUpdate).toBe(mockRequirement.userPermissions.updateRequirement);
      });
    });

    describe('canArchive', () => {
      it('returns value of `requirement.userPermissions.updateRequirement`', () => {
        expect(wrapper.vm.canArchive).toBe(mockRequirement.userPermissions.adminRequirement);
      });
    });
  });
});
