import { GlLink, GlSkeletonLoader, GlLoadingIcon, GlAvatarLink, GlAvatarLabeled } from '@gitlab/ui';
import { capitalize } from 'lodash-es';
import StatusDescription from 'ee/vulnerabilities/components/status_description.vue';
import {
  VULNERABILITY_STATE_OBJECTS,
  VULNERABILITY_STATES,
  DISMISSAL_REASONS,
} from 'ee/vulnerabilities/constants';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import UsersMockHelper from 'helpers/user_mock_data_helper';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';

const { detected, ...NON_DETECTED_STATE_OBJECTS } = VULNERABILITY_STATE_OBJECTS;
const NON_DETECTED_STATES = Object.keys(NON_DETECTED_STATE_OBJECTS);
const ALL_STATES = Object.keys(VULNERABILITY_STATES);

describe('Vulnerability status description component', () => {
  let wrapper;

  const timeAgo = () => wrapper.findComponent(TimeAgoTooltip);
  const pipelineLink = () => wrapper.findComponent(GlLink);
  const commitShaLink = () => wrapper.findComponent(GlLink);
  const avatarLink = () => wrapper.findComponent(GlAvatarLink);
  const avatarLabeled = () => wrapper.findComponent(GlAvatarLabeled);
  const userLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const skeletonLoader = () => wrapper.findComponent(GlSkeletonLoader);
  const statusEl = () => wrapper.findByTestId('status');
  const dismissalReasonEl = () => wrapper.findByTestId('dismissal-reason');

  // Create a date using the passed-in string, or just use the current time if nothing was passed in.
  const createDate = (value) => (value ? new Date(value) : new Date()).toISOString();

  const createWrapper = (props = {}) => {
    const vulnerability = props.vulnerability || { pipeline: {} };
    // Automatically create the ${v.state}_at property if it doesn't exist. Otherwise, every test would need to create
    // it manually for the component to mount properly.
    if (vulnerability.pipeline && vulnerability.state === 'detected') {
      vulnerability.pipeline.createdAt = vulnerability.pipeline.createdAt || createDate();
    } else {
      const propertyName = `${vulnerability.state}At`;
      vulnerability[propertyName] = vulnerability[propertyName] || createDate();
    }

    wrapper = mountExtended(StatusDescription, {
      propsData: { ...props, vulnerability },
    });
  };

  describe('state text', () => {
    // This also tests the dismissed state when no dismissalReason is provided
    it.each(ALL_STATES)('shows the correct string for the vulnerability state "%s"', (state) => {
      createWrapper({ vulnerability: { state, pipeline: {} } });

      expect(statusEl().text()).toBe(`${capitalize(state)}`);
    });

    it.each(Object.entries(DISMISSAL_REASONS))(
      'shows the correct string for the dismissal reason "%s"',
      (dismissalReason, translation) => {
        createWrapper({
          vulnerability: {
            state: 'dismissed',
            stateTransitions: [
              {
                dismissalReason,
              },
            ],
            pipeline: {},
          },
        });

        expect(statusEl().text()).toBe(`Dismissed`);
        expect(dismissalReasonEl().text()).toBe(translation);
      },
    );

    it.each`
      description                          | isStatusBolded
      ${'does not show bolded state text'} | ${false}
      ${'shows bolded state text'}         | ${true}
    `('$description if isStatusBolded is $isStatusBolded', ({ isStatusBolded }) => {
      createWrapper({
        vulnerability: { state: 'detected', pipeline: { createdAt: createDate('2001') } },
        isStatusBolded,
      });

      expect(statusEl().classes('gl-font-bold')).toBe(isStatusBolded);
    });
  });

  describe('time ago', () => {
    const pipelineDateString = createDate('2001');
    const detectedAtString = createDate('2002');

    it.each`
      description                | isVulnerabilityScanner | expectedTime
      ${'the pipeline created '} | ${false}               | ${pipelineDateString}
      ${'detection date'}        | ${true}                | ${detectedAtString}
    `(
      'uses $description when the vulnerability state is "detected"',
      ({ isVulnerabilityScanner, expectedTime }) => {
        createWrapper({
          vulnerability: {
            state: 'detected',
            pipeline: { createdAt: pipelineDateString },
            detectedAt: detectedAtString,
            scanner: { isVulnerabilityScanner },
          },
        });

        expect(timeAgo().props('time')).toBe(expectedTime);
      },
    );

    // The .map() is used to output the correct test name by doubling up the parameter, i.e. 'detected' -> ['detected', 'detected'].
    it.each(NON_DETECTED_STATES.map((x) => [x, x]))(
      'uses the "%s_at" property when the vulnerability state is "%s"',
      (state) => {
        const expectedDate = createDate();
        createWrapper({
          vulnerability: {
            state,
            pipeline: { createdAt: 'pipeline_created_at' },
            [`${state}At`]: expectedDate,
          },
        });

        expect(timeAgo().props('time')).toBe(expectedDate);
      },
    );
  });

  describe('pipeline link', () => {
    it('shows the pipeline link when the vulnerability state is "detected"', () => {
      createWrapper({
        vulnerability: { state: 'detected', pipeline: { url: 'pipeline/url' } },
      });

      expect(pipelineLink().attributes('href')).toBe('pipeline/url');
    });

    describe('when vulnerability scanner is true', () => {
      it('does not include the pipeline link', () => {
        createWrapper({
          vulnerability: {
            state: 'detected',
            pipeline: { url: 'pipeline/url' },
            scanner: { isVulnerabilityScanner: true },
          },
        });

        expect(pipelineLink().exists()).toBe(false);
      });
    });

    it.each(NON_DETECTED_STATES)(
      'does not show the pipeline link when the vulnerability state is "%s"',
      (state) => {
        createWrapper({
          vulnerability: { state, pipeline: { url: 'pipeline/url' } },
        });

        expect(pipelineLink().exists()).toBe(false); // The user avatar should be shown instead, those tests are handled separately.
      },
    );
  });

  describe('user', () => {
    it('shows a loading icon when the user is loading', () => {
      createWrapper({
        vulnerability: { state: 'dismissed' },
        isLoadingUser: true,
        user: UsersMockHelper.createRandomUser(), // Create a user so we can verify that the loading icon and the user is not shown at the same time.
      });

      expect(userLoadingIcon().exists()).toBe(true);
      expect(avatarLink().exists()).toBe(false);
    });

    it('shows the user when it exists and is not loading', () => {
      const user = UsersMockHelper.createRandomUser();
      createWrapper({
        vulnerability: { state: 'resolved' },
        user,
      });

      expect(userLoadingIcon().exists()).toBe(false);
      expect(avatarLink().attributes()).toMatchObject({
        href: user.web_url,
        'data-user-id': `${user.id}`,
        'data-username': user.username,
      });
      expect(avatarLink().classes('js-user-link')).toBe(true);
      expect(avatarLabeled().props('src')).toBe(user.avatar_url);
      expect(avatarLabeled().props('label')).toBe(user.name);
    });

    it('does not show the user when it does not exist and is not loading', () => {
      createWrapper();

      expect(userLoadingIcon().exists()).toBe(false);
      expect(avatarLink().exists()).toBe(false);
    });
  });

  describe('skeleton loader', () => {
    it('shows a skeleton loader and does not show anything else when the vulnerability is loading', () => {
      createWrapper({ isLoadingVulnerability: true });

      expect(skeletonLoader().exists()).toBe(true);
      expect(timeAgo().exists()).toBe(false);
      expect(pipelineLink().exists()).toBe(false);
    });

    it('hides the skeleton loader and shows everything else when the vulnerability is not loading', () => {
      createWrapper({ vulnerability: { state: 'detected', pipeline: {} } });

      expect(skeletonLoader().exists()).toBe(false);
      expect(timeAgo().exists()).toBe(true);
      expect(pipelineLink().exists()).toBe(true);
    });
  });

  describe('without pipeline data', () => {
    it('does not render any information', () => {
      // mount without a pipeline
      createWrapper({ vulnerability: { state: 'detected', pipeline: null } });

      expect(timeAgo().exists()).toBe(false);
      expect(pipelineLink().exists()).toBe(false);
    });
  });

  describe('commit sha link', () => {
    it('shows the link to the commit where the vulnerability was resolved on', () => {
      createWrapper({
        vulnerability: {
          resolvedOnDefaultBranch: true,
          representationInformation: {
            resolvedInCommitShaLink: 'https://gitlab.com/gitlab-org/gitlab/-/commit/0123456789',
            resolvedInCommitSha: '0123456789',
            createdAt: '2021-08-25T16:21:18Z',
          },
        },
      });

      expect(commitShaLink().attributes('href')).toBe(
        'https://gitlab.com/gitlab-org/gitlab/-/commit/0123456789',
      );
      expect(commitShaLink().text()).toBe('0123456789');
    });

    it('shows the timestamp of when the representationInformation was created', () => {
      const pipelineDate = createDate('2002');
      const representationInformationDate = createDate('2004');

      createWrapper({
        vulnerability: {
          pipeline: { createdAt: pipelineDate },
          resolvedOnDefaultBranch: true,
          representationInformation: {
            resolvedInCommitShaLink: 'https://gitlab.com/gitlab-org/gitlab/-/commit/0123456789',
            resolvedInCommitSha: '0123456789',
            createdAt: representationInformationDate,
          },
        },
      });
      expect(timeAgo().props('time')).toBe(representationInformationDate);
      expect(timeAgo().props('time')).not.toBe(pipelineDate);
    });

    it.each`
      resolvedOnDefaultBranch | resolvedInCommitShaLink
      ${false}                | ${'https://gitlab.com/gitlab/org/gitlab/-/commit/0123456789'}
      ${true}                 | ${null}
    `(
      'does not show the commitShaLink when resolvedOnDefaultBranch is "$resolvedOnDefaultBranch" and resolvedInCommitShaLink is "$resolvedInCommitShaLink"',
      ({ resolvedOnDefaultBranch, resolvedInCommitShaLink }) => {
        createWrapper({
          vulnerability: {
            resolvedOnDefaultBranch,
            representationInformation: {
              resolvedInCommitShaLink,
            },
          },
        });
        expect(commitShaLink().exists()).toBe(false);
      },
    );
  });
});
