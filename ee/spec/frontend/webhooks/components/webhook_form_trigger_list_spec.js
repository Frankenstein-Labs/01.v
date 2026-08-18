import { mountExtended } from 'helpers/vue_test_utils_helper';
import WebhookFormTriggerList from '~/webhooks/components/webhook_form_trigger_list.vue';
import waitForPromises from 'helpers/wait_for_promises';

describe('WebhookFormTriggerList ee-only', () => {
  let wrapper;

  const defaultInitialTriggers = {
    tagPushEvents: false,
    noteEvents: false,
    confidentialNoteEvents: false,
    issuesEvents: false,
    confidentialIssuesEvents: false,
    memberEvents: false,
    projectEvents: false,
    subgroupEvents: false,
    mergeRequestsEvents: false,
    jobEvents: false,
    pipelineEvents: false,
    wikiPageEvents: false,
    deploymentEvents: false,
    featureFlagEvents: false,
    releasesEvents: false,
    milestoneEvents: false,
    emojiEvents: false,
    resourceAccessTokenEvents: false,
    vulnerabilityEvents: false,
  };

  const createComponent = ({ props } = {}) => {
    wrapper = mountExtended(WebhookFormTriggerList, {
      propsData: {
        initialTriggers: defaultInitialTriggers,
        hasGroup: false,
        ...props,
      },
    });
  };

  const findGroupEventsTriggers = () => wrapper.findByTestId('groupEventsTriggers');
  const findVulnerabilityEventsTrigger = () => wrapper.findComponentByTestId('vulnerabilityEvents');
  const findTriggerByTestId = (key) => wrapper.findComponentByTestId(key);

  it('if not a group webhook, does not offer member, project, and subgroup events triggers', async () => {
    createComponent();
    await waitForPromises();
    expect(findGroupEventsTriggers().exists()).toBe(false);
  });

  it('renders VulnerabilityEventsTriggerItem', async () => {
    createComponent();
    await waitForPromises();
    expect(findVulnerabilityEventsTrigger()).not.toBe('');
    expect(findVulnerabilityEventsTrigger().props()).toMatchObject({
      triggerName: 'vulnerabilityEvents',
      inputName: 'hook[vulnerability_events]',
      label: 'Vulnerability events',
      helpText: 'A vulnerability is created or updated.',
    });
  });

  describe('when is group webhook form', () => {
    it('renders GroupEventsTriggerItems', async () => {
      createComponent({ props: { hasGroup: true } });
      await waitForPromises();
      expect(findGroupEventsTriggers().html()).not.toBe('');

      expect(findTriggerByTestId('memberEvents').props()).toMatchObject({
        helpText: 'A group member is created, updated, or removed.',
        inputName: 'hook[member_events]',
        label: 'Member events',
        triggerName: 'memberEvents',
        value: false,
      });

      expect(findTriggerByTestId('projectEvents').props()).toMatchObject({
        helpText: 'A project is created or removed.',
        inputName: 'hook[project_events]',
        label: 'Project events',
        triggerName: 'projectEvents',
        value: false,
      });

      expect(findTriggerByTestId('subgroupEvents').props()).toMatchObject({
        helpText: 'A subgroup is created or removed.',
        inputName: 'hook[subgroup_events]',
        label: 'Subgroup events',
        triggerName: 'subgroupEvents',
        value: false,
      });
    });
  });
});
