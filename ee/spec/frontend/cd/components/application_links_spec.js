import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlAlert } from '@gitlab/ui';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { confirmAction } from '~/lib/utils/confirm_via_gl_modal/confirm_via_gl_modal';
import ApplicationLinks from 'ee/cd/components/application_links.vue';
import LinkForm from 'ee/cd/components/link_form.vue';
import cdApplicationLinkCreateMutation from 'ee/cd/graphql/cd_application_link_create.mutation.graphql';
import cdApplicationLinkUpdateMutation from 'ee/cd/graphql/cd_application_link_update.mutation.graphql';
import cdApplicationLinkDeleteMutation from 'ee/cd/graphql/cd_application_link_delete.mutation.graphql';
import { makeCdApplicationLink } from './mock_data';

jest.mock('~/lib/utils/confirm_via_gl_modal/confirm_via_gl_modal');

Vue.use(VueApollo);

describe('ApplicationLinks', () => {
  let wrapper;
  let createHandler;
  let updateHandler;
  let deleteHandler;

  const applicationId = 'gid://gitlab/Cd::Application/5';
  const runbook = makeCdApplicationLink({
    id: 'gid://gitlab/Cd::ApplicationLink/1',
    name: 'runbook',
    linkType: 'RUNBOOK',
    url: 'https://runbook.example.com',
  });
  const dashboard = makeCdApplicationLink({
    id: 'gid://gitlab/Cd::ApplicationLink/2',
    name: 'dashboard',
    linkType: 'DASHBOARD',
    url: 'https://dashboard.example.com',
  });

  const createComponent = ({ links = [runbook, dashboard], full = false } = {}) => {
    const apolloProvider = createMockApollo([
      [cdApplicationLinkCreateMutation, createHandler],
      [cdApplicationLinkUpdateMutation, updateHandler],
      [cdApplicationLinkDeleteMutation, deleteHandler],
    ]);

    wrapper = shallowMountExtended(ApplicationLinks, {
      apolloProvider,
      propsData: { applicationId, links, full },
    });
  };

  const findAlert = () => wrapper.findComponent(GlAlert);
  const findForm = () => wrapper.findComponent(LinkForm);
  const findRows = () => wrapper.findAllByTestId('link-row');
  const findAddButton = () => wrapper.findComponentByTestId('add-link-button');
  const findHosts = () => wrapper.findAllByTestId('link-host');
  const findEditButtons = () => wrapper.findAllComponentsByTestId('edit-link-button');
  const findDeleteButtons = () => wrapper.findAllComponentsByTestId('delete-link-button');

  const clickAdd = async () => {
    findAddButton().vm.$emit('click');
    await nextTick();
  };

  const clickDelete = async () => {
    findDeleteButtons().at(0).vm.$emit('click');
    await waitForPromises();
  };

  beforeEach(() => {
    createHandler = jest.fn().mockResolvedValue({
      data: { cdApplicationLinkCreate: { errors: [] } },
    });
    updateHandler = jest.fn().mockResolvedValue({
      data: { cdApplicationLinkUpdate: { errors: [] } },
    });
    deleteHandler = jest.fn().mockResolvedValue({
      data: { cdApplicationLinkDelete: { errors: [] } },
    });
    confirmAction.mockResolvedValue(true);
  });

  describe('when there are links', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders a row per link', () => {
      expect(findRows()).toHaveLength(2);
      expect(findRows().at(0).text()).toContain('runbook');
      expect(findRows().at(1).text()).toContain('dashboard');
    });

    it('renders the add link button', () => {
      expect(findAddButton().exists()).toBe(true);
    });

    it('hides the host and per-row actions while collapsed', () => {
      expect(findHosts()).toHaveLength(0);
      expect(findEditButtons()).toHaveLength(0);
      expect(findDeleteButtons()).toHaveLength(0);
    });
  });

  describe('when there are no links', () => {
    beforeEach(() => {
      createComponent({ links: [] });
    });

    it('renders no rows but keeps the add link button', () => {
      expect(findRows()).toHaveLength(0);
      expect(findAddButton().exists()).toBe(true);
    });
  });

  describe('when expanded', () => {
    beforeEach(() => {
      createComponent({ full: true });
    });

    it('shows the host and per-row edit and delete actions on every row', () => {
      expect(findHosts().at(0).text()).toContain('runbook.example.com');
      expect(findEditButtons()).toHaveLength(2);
      expect(findDeleteButtons()).toHaveLength(2);
    });
  });

  describe('when the add link button is clicked', () => {
    beforeEach(async () => {
      createComponent();
      await clickAdd();
    });

    it('opens an empty form, hides the add link button, and asks to expand', () => {
      expect(findForm().exists()).toBe(true);
      expect(findForm().props('link')).toBe(null);
      expect(findAddButton().exists()).toBe(false);
      expect(wrapper.emitted('expand')).toHaveLength(1);
    });

    describe('when the form is submitted', () => {
      beforeEach(async () => {
        findForm().vm.$emit('submit', {
          linkType: 'RUNBOOK',
          name: 'New runbook',
          url: 'https://new.example.com',
        });
        await waitForPromises();
      });

      it('creates the link with the application id', () => {
        expect(createHandler).toHaveBeenCalledWith({
          input: {
            applicationId,
            linkType: 'RUNBOOK',
            name: 'New runbook',
            url: 'https://new.example.com',
          },
        });
      });

      it('notifies the parent of the creation and closes the form', () => {
        expect(wrapper.emitted('created')).toHaveLength(1);
        expect(findForm().exists()).toBe(false);
      });
    });

    describe('when the form is cancelled', () => {
      beforeEach(async () => {
        findForm().vm.$emit('cancel');
        await nextTick();
      });

      it('closes the form and restores the add link button', () => {
        expect(findForm().exists()).toBe(false);
        expect(findAddButton().exists()).toBe(true);
      });
    });
  });

  describe('when a link is edited', () => {
    beforeEach(async () => {
      createComponent({ full: true });
      findEditButtons().at(0).vm.$emit('click');
      await nextTick();
    });

    it('opens the form prefilled with the link', () => {
      expect(findForm().props('link')).toEqual(runbook);
    });

    describe('when the edit form is submitted', () => {
      beforeEach(async () => {
        findForm().vm.$emit('submit', {
          linkType: 'DASHBOARD',
          name: 'renamed',
          url: 'https://renamed.example.com',
        });
        await waitForPromises();
      });

      it('updates the link by id and notifies the parent', () => {
        expect(updateHandler).toHaveBeenCalledWith({
          input: {
            id: runbook.id,
            linkType: 'DASHBOARD',
            name: 'renamed',
            url: 'https://renamed.example.com',
          },
        });
        expect(wrapper.emitted('updated')).toHaveLength(1);
      });
    });
  });

  describe('when the user clicks delete link', () => {
    beforeEach(() => {
      createComponent({ full: true });
    });

    it('shows a confirmation', async () => {
      await clickDelete();

      expect(confirmAction).toHaveBeenCalled();
    });

    describe('when the deletion is confirmed', () => {
      beforeEach(async () => {
        confirmAction.mockResolvedValue(true);
        await clickDelete();
      });

      it('deletes the link by id', () => {
        expect(deleteHandler).toHaveBeenCalledWith({ input: { id: runbook.id } });
      });

      it('notifies the parent', () => {
        expect(wrapper.emitted('deleted')).toHaveLength(1);
      });
    });

    describe('when the deletion is not confirmed', () => {
      beforeEach(async () => {
        confirmAction.mockResolvedValue(false);
        await clickDelete();
      });

      it('does not call the delete mutation', () => {
        expect(deleteHandler).not.toHaveBeenCalled();
      });

      it('does not notify the parent', () => {
        expect(wrapper.emitted('deleted')).toBeUndefined();
      });
    });
  });

  describe('when a mutation returns errors', () => {
    beforeEach(async () => {
      createHandler = jest.fn().mockResolvedValue({
        data: { cdApplicationLinkCreate: { errors: ['Url has already been taken'] } },
      });
      createComponent();
      await clickAdd();
      findForm().vm.$emit('submit', {
        linkType: 'RUNBOOK',
        name: 'x',
        url: 'https://x.example.com',
      });
      await waitForPromises();
    });

    it('shows the error, keeps the form open, and does not notify the parent', () => {
      expect(findAlert().text()).toContain('Url has already been taken');
      expect(findForm().exists()).toBe(true);
      expect(wrapper.emitted('created')).toBeUndefined();
    });

    describe('when the corrected form is resubmitted', () => {
      beforeEach(async () => {
        createHandler.mockResolvedValue({
          data: { cdApplicationLinkCreate: { errors: [] } },
        });
        findForm().vm.$emit('submit', {
          linkType: 'RUNBOOK',
          name: 'x',
          url: 'https://corrected.example.com',
        });
        await waitForPromises();
      });

      it('retries the mutation, clears the error, and closes the form', () => {
        expect(createHandler).toHaveBeenCalledTimes(2);
        expect(findAlert().exists()).toBe(false);
        expect(findForm().exists()).toBe(false);
      });
    });
  });

  describe('when a mutation request fails', () => {
    beforeEach(async () => {
      jest.spyOn(Sentry, 'captureException').mockImplementation();
      deleteHandler = jest.fn().mockRejectedValue(new Error('boom'));
      createComponent({ full: true });
      findDeleteButtons().at(0).vm.$emit('click');
      await waitForPromises();
    });

    it('reports the error to Sentry and shows an alert', () => {
      expect(Sentry.captureException).toHaveBeenCalled();
      expect(findAlert().exists()).toBe(true);
    });
  });

  describe('when the card is collapsed while the form is open', () => {
    beforeEach(async () => {
      createComponent({ full: true });
      await clickAdd();
      wrapper.setProps({ full: false });
      await nextTick();
    });

    it('closes the form', () => {
      expect(findForm().exists()).toBe(false);
      expect(findAddButton().exists()).toBe(true);
    });
  });
});
