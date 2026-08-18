import { GlModal, GlSprintf } from '@gitlab/ui';
import MockAdapter from 'axios-mock-adapter';
import { nextTick } from 'vue';
import { markLocalStorageForQueuedAlert } from '~/invite_members/utils/trigger_successful_invite_alert';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import Api from '~/api';
import axios from '~/lib/utils/axios_utils';
import { HTTP_STATUS_CREATED } from '~/lib/utils/http_status';
import InviteMembersModal from '~/invite_members/components/invite_members_modal.vue';
import EEInviteModalBase from 'ee/invite_members/components/invite_modal_base.vue';
import CEInviteModalBase from '~/invite_members/components/invite_modal_base.vue';
import MembersTokenSelect from '~/invite_members/components/members_token_select.vue';
import { LEARN_GITLAB } from 'ee/invite_members/constants';
import eventHub from '~/invite_members/event_hub';
import ContentTransition from '~/invite_members/components/content_transition.vue';

import {
  propsData,
  postData,
  newProjectPath,
  user2,
  user3,
} from 'jest/invite_members/mock_data/member_modal';

import { GROUPS_INVITATIONS_PATH, invitationsApiResponse } from '../mock_data';

jest.mock('~/invite_members/utils/trigger_successful_invite_alert');

describe('EEInviteMembersModal', () => {
  let wrapper;
  let mock;

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(InviteMembersModal, {
      provide: {
        newProjectPath,
        name: propsData.name,
        overageMembersModalAvailable: true,
        rootGroupPath: 'root-group',
      },
      propsData: {
        usersLimitDataset: {},
        activeTrialDataset: {},
        fullPath: 'mygroup',
        ...propsData,
        ...props,
      },
      stubs: {
        InviteModalBase: EEInviteModalBase,
        CeInviteModalBase: CEInviteModalBase,
        ContentTransition,
        GlModal,
        GlSprintf,
      },
    });
  };

  const findBase = () => wrapper.findComponent(EEInviteModalBase);
  const findMembersSelect = () => wrapper.findComponent(MembersTokenSelect);
  const findActionButton = () => wrapper.findComponentByTestId('invite-modal-submit');
  const findMemberErrorAlert = () => wrapper.findByTestId('alert-member-error');

  const emitClickFromModal = (findButton) => () =>
    findButton().vm.$emit('click', { preventDefault: jest.fn() });

  const clickInviteButton = emitClickFromModal(findActionButton);

  const triggerOpenModal = ({ mode = 'default', source } = {}) => {
    eventHub.$emit('open-modal', { mode, source });
  };

  const triggerMembersTokenSelect = async (val) => {
    findMembersSelect().vm.$emit('input', val);

    await nextTick();
  };

  const mockInvitationsApi = (code, data) => {
    mock.onPost(GROUPS_INVITATIONS_PATH).replyOnce(code, data);
  };

  beforeEach(() => {
    gon.api_version = 'v4';
    mock = new MockAdapter(axios);
  });

  afterEach(() => {
    mock.restore();
  });

  describe('when member invitation is pending approval', () => {
    describe('when there is on error', () => {
      beforeEach(() => {
        createComponent();
        triggerMembersTokenSelect([user3]);
        mockInvitationsApi(HTTP_STATUS_CREATED, invitationsApiResponse.MEMBER_PENDING_APPROVAL);
        clickInviteButton();
        return waitForPromises();
      });

      it('marks local storage for queued requests alert', () => {
        expect(markLocalStorageForQueuedAlert).toHaveBeenCalled();
      });
    });

    describe('when there is an error and a pending member in the invitation', () => {
      beforeEach(() => {
        createComponent();
        triggerMembersTokenSelect([user3]);
        mockInvitationsApi(HTTP_STATUS_CREATED, invitationsApiResponse.ERROR_AND_PENDING_APPROVAL);
        clickInviteButton();
        return waitForPromises();
      });

      it('shows error alert', () => {
        expect(findMemberErrorAlert().exists()).toBe(true);
      });

      it('clears error alert when member select is cleared', async () => {
        findMembersSelect().vm.$emit('clear');
        await nextTick();

        expect(findMemberErrorAlert().exists()).toBe(false);
      });

      it('does not mark local storage for queued requests alert', () => {
        expect(markLocalStorageForQueuedAlert).not.toHaveBeenCalled();
      });
    });
  });

  describe('passes correct props to InviteModalBase', () => {
    it('set isProject', async () => {
      createComponent();
      await waitForPromises();

      expect(findBase().props('isProject')).toBe(false);
    });

    describe('hasErrorDuringInvite prop', () => {
      it('passes hasErrorDuringInvite as true when there are invalid members', async () => {
        createComponent();
        wrapper.vm.invalidMembers = { foo: 'error message' };
        await nextTick();

        expect(findBase().props('hasErrorDuringInvite')).toBe(true);
      });

      it('passes hasErrorDuringInvite as false when there are no invalid members', async () => {
        createComponent();
        wrapper.vm.invalidMembers = {};
        await nextTick();

        expect(findBase().props('hasErrorDuringInvite')).toBe(false);
      });
    });
  });

  describe('when on the Learn GitLab page', () => {
    describe('when member is added successfully', () => {
      beforeEach(async () => {
        createComponent();

        await triggerMembersTokenSelect([user2, user3]);

        jest.spyOn(Api, 'inviteGroupMembers').mockResolvedValue({ data: postData });

        clickInviteButton();
      });

      it('emits the `showSuccessfulInvitationsAlert` event', async () => {
        await triggerOpenModal({ source: LEARN_GITLAB });

        jest.spyOn(eventHub, '$emit').mockImplementation();

        clickInviteButton();

        await waitForPromises();

        expect(eventHub.$emit).toHaveBeenCalledWith('showSuccessfulInvitationsAlert');
      });
    });
  });
});
