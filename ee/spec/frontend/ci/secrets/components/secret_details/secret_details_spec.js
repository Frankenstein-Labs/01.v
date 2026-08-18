import { GlLabel } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import SecretDetails from 'ee/ci/secrets/components/secret_details/secret_details.vue';
import { ENTITY_GROUP, ENTITY_PROJECT } from 'ee/ci/secrets/constants';
import { mockGroupSecret, mockProjectSecret } from '../../mock_data';

describe('SecretDetails component', () => {
  let wrapper;

  const findBranches = () => wrapper.findByTestId('secret-details-branches');
  const findDescription = () => wrapper.findByTestId('secret-details-description');
  const findProtectedBranches = () => wrapper.findByTestId('secret-details-protected-branches');
  const findRotationReminder = () => wrapper.findByTestId('secret-details-rotation-reminder');
  const findHealthStatus = () => wrapper.findComponentByTestId('secret-details-health-status');
  const findEnvironments = () => wrapper.findComponent(GlLabel);

  const createComponent = ({ customSecret, context = ENTITY_PROJECT } = {}) => {
    const secretData = context === ENTITY_PROJECT ? mockProjectSecret() : mockGroupSecret();
    wrapper = shallowMountExtended(SecretDetails, {
      propsData: {
        secret: {
          ...secretData,
          ...customSecret,
        },
      },
    });
  };

  describe.each`
    context           | description                   | renderBranchFields | renderProtectedBranches | customSecret
    ${ENTITY_PROJECT} | ${'This is a project secret'} | ${true}            | ${false}                | ${{}}
    ${ENTITY_GROUP}   | ${'This is a group secret'}   | ${false}           | ${true}                 | ${{ protected: true }}
  `(
    'secret details template for $context context',
    ({ context, description, renderBranchFields, renderProtectedBranches, customSecret }) => {
      beforeEach(() => {
        createComponent({ context, customSecret });
      });

      it('correctly renders branches field', () => {
        expect(findBranches().exists()).toBe(renderBranchFields);
      });

      it('correctly renders protected branches field', () => {
        expect(findProtectedBranches().exists()).toBe(renderProtectedBranches);
      });

      it('renders and formats secret information', () => {
        expect(findDescription().text()).toBe(description);
        expect(findEnvironments().props('title')).toBe('env::staging');
      });

      it('renders environment label correctly', () => {
        createComponent({ context, customSecret: { environment: 'staging' } });

        expect(findEnvironments().props('title')).toBe('env::staging');
      });

      it('renders "*" environment as "All (default)"', () => {
        createComponent({ context, customSecret: { environment: '*' } });

        expect(findEnvironments().props('title')).toBe('env::All (default)');
      });

      describe('with rotation info', () => {
        beforeEach(() => {
          createComponent({
            context,
            customSecret: {
              rotationInfo: {
                rotationIntervalDays: 7,
                nextReminderAt: '2025-10-08T00:00:00Z',
                status: 'APPROACHING',
              },
            },
          });
        });

        it('renders rotation reminder information', () => {
          expect(findRotationReminder().text()).toBe('Oct 8, 2025 (Every 7 days)');
        });
      });

      describe('with required fields only', () => {
        beforeEach(() => {
          createComponent({
            context,
            customSecret: {
              description: undefined,
            },
          });
        });

        it("renders 'None' for optional fields that don't have values", () => {
          expect(findDescription().text()).toBe('None');

          if (context === ENTITY_PROJECT) {
            expect(findRotationReminder().text()).toBe('None');
          }
        });
      });

      describe('health status', () => {
        it.each`
          status                  | text                 | variant      | tooltip
          ${'COMPLETED'}          | ${'Healthy'}         | ${'success'} | ${'Secret created or updated successfully.'}
          ${'CREATE_STALE'}       | ${'Needs attention'} | ${'danger'}  | ${'Secret creation failed. Delete the secret and try again.'}
          ${'UPDATE_STALE'}       | ${'Needs attention'} | ${'danger'}  | ${'Secret update failed. Retry the update or delete the secret.'}
          ${'CREATE_IN_PROGRESS'} | ${'Creating'}        | ${'neutral'} | ${'Secret is being created.'}
          ${'UPDATE_IN_PROGRESS'} | ${'Updating'}        | ${'neutral'} | ${'Secret is being updated.'}
        `('renders $status status', ({ status, text, tooltip, variant }) => {
          createComponent({ customSecret: { status }, context });

          expect(findHealthStatus().text()).toBe(text);
          expect(findHealthStatus().props('variant')).toBe(variant);
          expect(findHealthStatus().attributes('title')).toBe(tooltip);
        });
      });
    },
  );

  describe('branches field in project context', () => {
    it.each`
      branchValue | expectedLabel
      ${'*'}      | ${'All (default)'}
      ${'main'}   | ${'main'}
    `(
      'renders "$expectedLabel" label when branch is $branchValue',
      ({ branchValue, expectedLabel }) => {
        createComponent({
          context: ENTITY_PROJECT,
          customSecret: { branch: branchValue },
        });

        expect(findBranches().text()).toBe(expectedLabel);
      },
    );
  });

  describe('protected branches field in group context', () => {
    it.each`
      protectedValue | expectedLabel
      ${true}        | ${'True'}
      ${false}       | ${'False'}
    `(
      'renders "$expectedLabel" label when protected is $protectedValue',
      ({ protectedValue, expectedLabel }) => {
        createComponent({
          context: ENTITY_GROUP,
          customSecret: { protected: protectedValue },
        });

        expect(findProtectedBranches().text()).toBe(expectedLabel);
      },
    );
  });
});
