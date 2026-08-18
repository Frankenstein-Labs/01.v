import { GlAvatar, GlAvatarLink, GlDisclosureDropdown, GlIcon, GlModal } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import { RENDER_ALL_SLOTS_TEMPLATE, stubComponent } from 'helpers/stub_component';
import waitForPromises from 'helpers/wait_for_promises';
import projectInfoQuery from 'ee_else_ce/repository/queries/project_info.query.graphql';
import lockPathMutation from '~/repository/mutations/lock_path.mutation.graphql';
import UsersCache from '~/lib/utils/users_cache';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';
import { projectMock, lockPathMutationMock } from 'ee_jest/repository/mock_data';
import LockButton from 'ee_component/repository/components/header_area/lock_button.vue';
import { createAlert } from '~/alert';

Vue.use(VueApollo);
jest.mock('~/alert');
jest.mock('~/lib/utils/users_cache');

describe('LockButton component', () => {
  let wrapper;
  let fakeApollo;

  const mockLockUser = {
    id: 'gid://gitlab/User/2',
    username: 'user2',
    name: 'User2',
    avatarUrl: 'https://www.gravatar.com/avatar/user2?s=80',
    webPath: '/user2',
  };

  const lockedProps = {
    isLocked: true,
    lockUser: mockLockUser,
    lockedAt: '2026-07-13T00:00:00Z',
    canDestroyLock: true,
  };

  const lockPathMutationResolver = jest.fn().mockResolvedValue(lockPathMutationMock);
  const projectInfoResolver = jest.fn().mockResolvedValue({ data: { project: projectMock } });
  const mockToastShow = jest.fn();

  const createComponent = ({
    props = {},
    provided = {},
    mutationResolver = lockPathMutationResolver,
    slots = {},
  } = {}) => {
    fakeApollo = createMockApollo([
      [lockPathMutation, mutationResolver],
      [projectInfoQuery, projectInfoResolver],
    ]);

    wrapper = mountExtended(LockButton, {
      apolloProvider: fakeApollo,
      provide: {
        glFeatures: {
          repositoryLockInformation: true,
        },
        ...provided,
      },
      propsData: {
        isLocked: false,
        projectPath: 'some/project',
        path: 'some/file.js',
        ...props,
      },
      slots,
      stubs: {
        GlModal: stubComponent(GlModal, { template: RENDER_ALL_SLOTS_TEMPLATE }),
      },
      mocks: {
        $toast: {
          show: mockToastShow,
        },
      },
    });
  };

  const findLockButton = () => wrapper.findComponentByTestId('lock-button');
  const findDisclosure = () => wrapper.findComponent(GlDisclosureDropdown);
  const findDisclosureToggle = () => wrapper.findByTestId('lock-disclosure-toggle');
  const findDisclosureHeader = () => wrapper.findByTestId('lock-disclosure-header');
  const findTimeAgo = () => wrapper.findComponent(TimeAgoTooltip);
  const findLockUserCard = () => wrapper.findByTestId('lock-user-card');
  const findLockUserLink = () => wrapper.findComponent(GlAvatarLink);
  const findUnlockButton = () => wrapper.findComponentByTestId('unlock-button');
  const findNoPermissionMessage = () => wrapper.findByTestId('no-permission-message');
  const findModal = () => wrapper.findComponent(GlModal);
  const clickSubmit = () => findModal().vm.$emit('primary');
  const openDisclosure = () => findDisclosure().vm.$emit('shown');

  beforeEach(() => {
    UsersCache.retrieveById.mockResolvedValue({
      job_title: 'Senior Product Designer - Source Code',
      organization: 'GitLab',
      location: 'Sydney, Australia',
      local_time: '2:23 PM',
    });
  });

  afterEach(() => {
    fakeApollo = null;
  });

  describe('when repositoryLockInformation feature flag is off', () => {
    it('renders nothing', () => {
      createComponent({
        props: { isLocked: true, lockUser: mockLockUser, canCreateLock: true },
        provided: { glFeatures: { repositoryLockInformation: false } },
      });

      expect(wrapper.find('*').exists()).toBe(false);
    });
  });

  describe('when the file is not locked', () => {
    describe('when user cannot create a lock', () => {
      beforeEach(() => {
        createComponent({ props: { canCreateLock: false } });
      });

      it('renders nothing', () => {
        expect(wrapper.find('*').exists()).toBe(false);
      });
    });

    describe('when user can create a lock', () => {
      beforeEach(() => {
        createComponent({ props: { canCreateLock: true } });
      });

      it('renders a Lock button without an icon and no disclosure', () => {
        expect(findLockButton().text()).toBe('Lock');
        expect(findLockButton().props('icon')).toBe('');
        expect(findDisclosure().exists()).toBe(false);
      });

      it('opens the confirm modal when clicked', async () => {
        await findLockButton().trigger('click');

        expect(findModal().props('visible')).toBe(true);
        expect(findModal().props('title')).toBe('Lock file?');
        expect(findModal().text()).toBe('Are you sure you want to lock the "file.js" file?');
        expect(findModal().props('actionPrimary')).toMatchObject({ text: 'Lock' });
      });

      it('executes the lock mutation, refetches project info, and shows a toast', async () => {
        await findLockButton().trigger('click');
        clickSubmit();
        await waitForPromises();

        expect(lockPathMutationResolver).toHaveBeenCalledWith({
          filePath: 'some/file.js',
          projectPath: 'some/project',
          lock: true,
        });
        expect(projectInfoResolver).toHaveBeenCalledWith({ projectPath: 'some/project' });
        expect(mockToastShow).toHaveBeenCalledWith('The file is locked.');
      });

      it('does not execute the mutation when not confirmed', async () => {
        await findLockButton().trigger('click');

        expect(lockPathMutationResolver).not.toHaveBeenCalled();
      });

      it('syncs the lock state when the isLocked prop changes', async () => {
        await wrapper.setProps({ isLocked: true });

        expect(findLockButton().exists()).toBe(false);
        expect(findDisclosure().exists()).toBe(true);
      });

      describe('when the mutation fails', () => {
        beforeEach(() => {
          createComponent({
            props: { canCreateLock: true },
            mutationResolver: jest.fn().mockRejectedValue(new Error('GraphQL error')),
          });
        });

        it('keeps the unlocked state', async () => {
          await findLockButton().trigger('click');
          clickSubmit();
          await waitForPromises();

          expect(findLockButton().exists()).toBe(true);
          expect(findDisclosure().exists()).toBe(false);
        });
      });
    });
  });

  describe('when the file is locked', () => {
    beforeEach(() => {
      createComponent({ props: lockedProps });
    });

    it('renders the disclosure toggle with the lock user avatar and Locked label', () => {
      expect(findDisclosureToggle().text()).toContain('Locked');
      expect(findDisclosureToggle().findComponent(GlAvatar).props('src')).toBe(
        mockLockUser.avatarUrl,
      );
      expect(findDisclosureToggle().attributes('aria-label')).toBe('Locked by User2');
      expect(findLockButton().exists()).toBe(false);
    });

    it('renders the disclosure header with locker name and lock time', () => {
      expect(findDisclosureHeader().text()).toContain('Locked by User2');
      expect(findTimeAgo().props('time')).toBe('2026-07-13T00:00:00Z');
    });

    it('renders the lock user card linked to the user profile', () => {
      expect(findLockUserCard().text()).toContain('User2');
      expect(findLockUserCard().text()).toContain('@user2');
      expect(findLockUserLink().attributes('href')).toBe(mockLockUser.webPath);
    });

    describe('when the disclosure is opened', () => {
      beforeEach(async () => {
        openDisclosure();
        await waitForPromises();
      });

      it('fetches and renders additional user details', () => {
        expect(UsersCache.retrieveById).toHaveBeenCalledWith(2);
        expect(findLockUserCard().text()).toContain('Senior Product Designer - Source Code');
        expect(findLockUserCard().text()).toContain('GitLab');
        expect(findLockUserCard().text()).toContain('Sydney, Australia');
        expect(findLockUserCard().text()).toContain('2:23 PM');
      });
    });

    describe('when some user details are empty', () => {
      beforeEach(async () => {
        UsersCache.retrieveById.mockResolvedValue({
          job_title: 'Senior Product Designer - Source Code',
          organization: null,
          location: '',
          local_time: undefined,
        });
        openDisclosure();
        await waitForPromises();
      });

      it('renders only the rows that have a value', () => {
        const iconNames = findLockUserCard()
          .findAllComponents(GlIcon)
          .wrappers.map((icon) => icon.props('name'));

        expect(iconNames).toEqual(['work']);
      });
    });

    describe('when user details fail to load', () => {
      beforeEach(async () => {
        UsersCache.retrieveById.mockRejectedValue(new Error('Request failed'));
        openDisclosure();
        await waitForPromises();
      });

      it('keeps the disclosure usable', () => {
        expect(findLockUserCard().text()).toContain('User2');
        expect(createAlert).not.toHaveBeenCalled();
      });
    });

    describe('when user can unlock', () => {
      it('renders the Unlock file button and does not render the no-permission message', () => {
        expect(findUnlockButton().text()).toBe('Unlock file');
        expect(findNoPermissionMessage().exists()).toBe(false);
      });

      it('opens the confirm modal from the Unlock file button', async () => {
        await findUnlockButton().trigger('click');

        expect(findModal().props('visible')).toBe(true);
        expect(findModal().props('title')).toBe('Unlock file?');
        expect(findModal().text()).toBe('Are you sure you want to unlock the "file.js" file?');
      });

      it('executes the unlock mutation, refetches project info, and shows a toast', async () => {
        await findUnlockButton().trigger('click');
        clickSubmit();
        await waitForPromises();

        expect(lockPathMutationResolver).toHaveBeenCalledWith({
          filePath: 'some/file.js',
          projectPath: 'some/project',
          lock: false,
        });
        expect(projectInfoResolver).toHaveBeenCalledWith({ projectPath: 'some/project' });
        expect(mockToastShow).toHaveBeenCalledWith('The file is unlocked.');
      });
    });

    describe('when user cannot unlock', () => {
      it('renders the no permission message instead of the Unlock file button', () => {
        createComponent({ props: { ...lockedProps, canDestroyLock: false } });

        expect(findUnlockButton().exists()).toBe(false);
        expect(findNoPermissionMessage().text()).toBe(
          'You do not have permission to unlock this file.',
        );
      });
    });

    describe('when lock user is not available', () => {
      beforeEach(() => {
        createComponent({
          props: { ...lockedProps, lockUser: null, canDestroyLock: false },
        });
      });

      it('renders the toggle with a generic aria-label, no avatar, and no user card', () => {
        expect(findDisclosureToggle().attributes('aria-label')).toBe('Locked');
        expect(findDisclosureToggle().findComponent(GlAvatar).exists()).toBe(false);
        expect(findLockUserCard().exists()).toBe(false);
      });
    });

    describe('slots', () => {
      it('renders content passed to the disclosure-alert slot inside the disclosure', () => {
        createComponent({
          props: lockedProps,
          slots: {
            'disclosure-alert': '<div data-testid="directory-lock-alert">Alert content</div>',
          },
        });

        expect(wrapper.findByTestId('directory-lock-alert').text()).toBe('Alert content');
      });

      it('replaces the default unlock action with content passed to the footer slot', () => {
        createComponent({
          props: lockedProps,
          slots: {
            footer: '<button data-testid="view-locked-file-button">View locked file</button>',
          },
        });

        expect(wrapper.findByTestId('view-locked-file-button').exists()).toBe(true);
        expect(findUnlockButton().exists()).toBe(false);
        expect(findNoPermissionMessage().exists()).toBe(false);
      });
    });
  });

  describe('when the mutation fails', () => {
    beforeEach(async () => {
      createComponent({
        props: lockedProps,
        mutationResolver: jest.fn().mockRejectedValue(new Error('Request failed')),
      });

      await findUnlockButton().trigger('click');
      clickSubmit();
      await waitForPromises();
    });

    it('renders an alert and does not show a toast', () => {
      expect(createAlert).toHaveBeenCalledWith({
        message: 'An error occurred while editing lock information, please try again.',
        captureError: true,
        error: expect.any(Error),
      });
      expect(mockToastShow).not.toHaveBeenCalled();
    });
  });

  describe('when the mutation response contains errors', () => {
    beforeEach(async () => {
      createComponent({
        props: lockedProps,
        mutationResolver: jest.fn().mockResolvedValue({
          data: {
            projectSetLocked: {
              project: null,
              errors: ['You are not authorized to lock this file.'],
              __typename: 'ProjectSetLockedPayload',
            },
          },
        }),
      });

      await findUnlockButton().trigger('click');
      clickSubmit();
      await waitForPromises();
    });

    it('renders an alert with the returned message and does not show a toast', () => {
      expect(createAlert).toHaveBeenCalledWith({
        message: 'You are not authorized to lock this file.',
      });
      expect(mockToastShow).not.toHaveBeenCalled();
    });
  });

  describe('when resourceType is directory', () => {
    const directoryProps = {
      path: 'some/directory',
      resourceType: 'directory',
    };

    it('uses directory wording in the lock confirm modal and toast', async () => {
      createComponent({ props: { ...directoryProps, canCreateLock: true } });

      await findLockButton().trigger('click');

      expect(findModal().props('title')).toBe('Lock directory?');
      expect(findModal().text()).toBe('Are you sure you want to lock the "directory" directory?');

      clickSubmit();
      await waitForPromises();

      expect(lockPathMutationResolver).toHaveBeenCalledWith({
        filePath: 'some/directory',
        projectPath: 'some/project',
        lock: true,
      });
      expect(mockToastShow).toHaveBeenCalledWith('The directory is locked.');
    });

    it('uses directory wording for the unlock action and modal', async () => {
      createComponent({
        props: {
          ...directoryProps,
          isLocked: true,
          lockUser: mockLockUser,
          canDestroyLock: true,
        },
      });

      expect(findUnlockButton().text()).toBe('Unlock directory');

      await findUnlockButton().trigger('click');

      expect(findModal().props('title')).toBe('Unlock directory?');

      clickSubmit();
      await waitForPromises();

      expect(mockToastShow).toHaveBeenCalledWith('The directory is unlocked.');
    });
  });
});
