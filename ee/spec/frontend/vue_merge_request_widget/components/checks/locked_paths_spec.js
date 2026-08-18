import { mountExtended } from 'helpers/vue_test_utils_helper';
import LockedPathsComponent from 'ee/vue_merge_request_widget/components/checks/locked_paths.vue';

describe('Locked paths merge checks component', () => {
  let wrapper;

  const findActionButton = () => wrapper.findByTestId('extension-actions-button');

  function createComponent({ status = 'FAILED', pathLocksPath = '/path_locks' } = {}) {
    wrapper = mountExtended(LockedPathsComponent, {
      propsData: {
        mr: {
          pathLocksPath,
        },
        check: {
          identifier: 'locked_paths',
          status,
        },
      },
    });
  }

  it.each`
    status       | pathLocksPath    | existsText           | exists
    ${'FAILED'}  | ${'/path_locks'} | ${'renders'}         | ${true}
    ${'FAILED'}  | ${''}            | ${'does not render'} | ${false}
    ${'SUCCESS'} | ${''}            | ${'does not render'} | ${false}
    ${'SUCCESS'} | ${'/path_locks'} | ${'does not render'} | ${false}
  `(
    '$existsText the action button when status is $status and pathLocksPath is $pathLocksPath',
    ({ status, pathLocksPath, exists }) => {
      createComponent({ status, pathLocksPath });

      expect(findActionButton().exists()).toBe(exists);
    },
  );
});
