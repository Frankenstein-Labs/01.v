import { flowFromRolloutSteps, rolloutProgress } from 'ee/cd/flow_from_rollout';

const rolloutStep = ({
  type,
  name = null,
  state = 'SUCCESS',
  environment = null,
  steps,
  params = null,
}) => ({
  stepType: type,
  name,
  state,
  params,
  environment: environment ? { name: environment } : null,
  ...(steps ? { steps } : {}),
});

const weights = (...values) => ({ services: values.map((weight) => ({ name: 'nginx', weight })) });

const stage = (name, steps, state = 'SUCCESS') =>
  rolloutStep({ type: 'com.gitlab.cd.steps.stage', name, state, steps });

const deploy = (environment, state) =>
  rolloutStep({ type: 'com.gitlab.cd.argo.rolling.deploy', environment, state });

const wait = (seconds) => rolloutStep({ type: 'com.gitlab.cd.steps.wait', params: { seconds } });

const build = (rolloutSteps) => flowFromRolloutSteps(rolloutSteps);

const stepTitles = (item) => item.steps.map(({ title }) => title);

describe('flowFromRolloutSteps', () => {
  it('returns an empty flow when there are no steps', () => {
    expect(flowFromRolloutSteps(null)).toEqual([]);
    expect(flowFromRolloutSteps(undefined)).toEqual([]);
  });

  describe('item kinds', () => {
    it('maps a stage step to a stage and anything else to a bare step', () => {
      const items = build([stage('preprod', [deploy('staging')]), wait(30)]);

      expect(items.map(({ kind }) => kind)).toEqual(['stage', 'step']);
    });

    it('preserves the order the API returned', () => {
      const items = build([wait(30), stage('middle', [deploy('env')]), wait(600)]);

      expect(items.map(({ title }) => title)).toEqual(['Wait 30s', 'middle', 'Wait 10min']);
    });
  });

  describe('stage steps', () => {
    it("keeps a stage's children in flow order, since they run one after another", () => {
      const [item] = build([
        stage('production', [wait(30), deploy('eu'), deploy('us'), wait(600)]),
      ]);

      expect(stepTitles(item)).toEqual([
        'Wait 30s',
        'Rolling deploy',
        'Rolling deploy',
        'Wait 10min',
      ]);
    });

    it('keeps repeated environments in place rather than grouping them', () => {
      const [item] = build([stage('s', [deploy('eu'), deploy('us'), deploy('eu')])]);

      expect(item.steps.map(({ subtitle }) => subtitle)).toEqual(['eu', 'us', 'eu']);
    });

    it.each([
      ['null', null],
      ['undefined', undefined],
      ['empty', []],
    ])('yields no steps when a stage has %s children', (_scenario, steps) => {
      const [item] = build([
        {
          stepType: 'com.gitlab.cd.steps.stage',
          name: 's',
          state: 'SUCCESS',
          environment: null,
          steps,
        },
      ]);

      expect(item.steps).toEqual([]);
      expect(item.environmentsCount).toBe(0);
    });
  });

  describe('environmentsCount', () => {
    it.each([
      ['no environments', [wait(30)], 0],
      ['one environment used twice', [deploy('eu'), deploy('eu')], 1],
      ['two environments', [deploy('eu'), deploy('us')], 2],
    ])('counts %s as %i', (_scenario, steps, expected) => {
      const [item] = build([stage('s', steps)]);

      expect(item.environmentsCount).toBe(expected);
    });
  });

  describe('categories', () => {
    it.each([
      ['com.gitlab.cd.argo.rolling.deploy', 'deploy'],
      ['com.gitlab.cd.argo.canary.deploy', 'deploy'],
      ['com.gitlab.cd.argo.canary.promote', 'deploy'],
      ['com.gitlab.cd.steps.approval', 'approve'],
      ['com.gitlab.cd.steps.wait', 'wait'],
    ])('maps %s to the %s category', (type, expected) => {
      const [item] = build([rolloutStep({ type, name: 'x' })]);

      expect(item.category).toBe(expected);
    });

    it('leaves the category empty for a step type it does not know', () => {
      const [item] = build([rolloutStep({ type: 'com.gitlab.cd.argo.bluegreen.switch' })]);

      expect(item.category).toBeNull();
    });
  });

  describe('states', () => {
    it.each([
      ['PENDING'],
      ['RUNNING'],
      ['AWAITING_APPROVAL'],
      ['APPROVED'],
      ['REJECTED'],
      ['SUCCESS'],
      ['FAILED'],
      ['SKIPPED'],
      ['CANCELLED'],
    ])('passes %s through untranslated', (state) => {
      const [item] = build([rolloutStep({ type: 'com.gitlab.cd.steps.wait', name: 'x', state })]);

      expect(item.state).toBe(state);
    });

    it('passes a state it does not recognise through, rather than inventing one', () => {
      const [item] = build([
        rolloutStep({ type: 'com.gitlab.cd.steps.wait', name: 'x', state: 'BRAND_NEW' }),
      ]);

      expect(item.state).toBe('BRAND_NEW');
    });
  });

  describe('titles', () => {
    it.each([
      ['com.gitlab.cd.argo.rolling.deploy', 'Rolling deploy'],
      ['com.gitlab.cd.argo.canary.deploy', 'Canary deploy'],
      ['com.gitlab.cd.argo.canary.promote', 'Canary promote'],
      ['com.gitlab.cd.steps.wait', 'Wait'],
      ['com.gitlab.cd.steps.approval', 'Approval'],
      ['com.gitlab.cd.argo.bluegreen.switch', 'Bluegreen switch'],
    ])('titles %s as "%s", dropping the driver that implements it', (type, expected) => {
      const [item] = build([rolloutStep({ type })]);

      expect(item.title).toBe(expected);
    });

    it.each([
      ['com.gitlab.cd.slack.notify', 'Slack notify'],
      ['com.gitlab.cd.duo.review', 'Duo review'],
      ['com.gitlab.cd.servicenow.change_request', 'Servicenow change request'],
    ])('titles %s as "%s", keeping the provider that names it', (type, expected) => {
      const [item] = build([rolloutStep({ type })]);

      expect(item.title).toBe(expected);
    });

    it('titles a type with no action after the namespace as "Steps"', () => {
      const [item] = build([rolloutStep({ type: 'com.gitlab.cd.steps' })]);

      expect(item.title).toBe('Steps');
    });

    it('titles a stage with no name as "Stage"', () => {
      const [item] = build([stage(null, [deploy('eu')])]);

      expect(item.title).toBe('Stage');
    });

    describe('when the step has a name', () => {
      it('uses the name', () => {
        const [item] = build([
          rolloutStep({ type: 'com.gitlab.cd.argo.rolling.deploy', name: 'Ship it' }),
        ]);

        expect(item.title).toBe('Ship it');
      });

      it('uses the name over the weight', () => {
        const [item] = build([
          rolloutStep({
            type: 'com.gitlab.cd.argo.canary.deploy',
            name: 'Canary',
            params: weights(33),
          }),
        ]);

        expect(item.title).toBe('Canary');
      });
    });

    describe('when the step shifts traffic', () => {
      it.each([
        ['com.gitlab.cd.argo.canary.deploy', 33, 'Canary 33%'],
        ['com.gitlab.cd.argo.canary.promote', 100, 'Canary 100%'],
        ['com.gitlab.cd.argo.canary.deploy', 0, 'Canary 0%'],
      ])('titles %s at weight %i as "%s"', (type, weight, expected) => {
        const [item] = build([rolloutStep({ type, params: weights(weight) })]);

        expect(item.title).toBe(expected);
      });

      describe('when every service moves to the same weight', () => {
        it('uses that weight', () => {
          const [item] = build([
            rolloutStep({ type: 'com.gitlab.cd.argo.canary.promote', params: weights(50, 50) }),
          ]);

          expect(item.title).toBe('Canary 50%');
        });
      });

      describe('when services move to different weights', () => {
        it('omits the weight', () => {
          const [item] = build([
            rolloutStep({ type: 'com.gitlab.cd.argo.canary.deploy', params: weights(33, 50) }),
          ]);

          expect(item.title).toBe('Canary deploy');
        });
      });
    });

    describe('when the step waits', () => {
      it.each([
        [30, 'Wait 30s'],
        [600, 'Wait 10min'],
        [7200, 'Wait 2h'],
        [0, 'Wait 0s'],
      ])('titles a wait of %i seconds as "%s"', (seconds, expected) => {
        const [item] = build([
          rolloutStep({ type: 'com.gitlab.cd.steps.wait', params: { seconds } }),
        ]);

        expect(item.title).toBe(expected);
      });
    });
  });

  describe('subtitles', () => {
    it('uses the environment name', () => {
      const [item] = build([deploy('prod-eu-west-1')]);

      expect(item.subtitle).toBe('prod-eu-west-1');
    });

    it('is empty for a step that targets no environment', () => {
      const [item] = build([wait(30)]);

      expect(item.subtitle).toBe('');
    });
  });
});

describe('rolloutProgress', () => {
  const finished = ['SUCCESS', 'FAILED', 'SKIPPED', 'CANCELLED', 'APPROVED', 'REJECTED'];
  const running = ['PENDING', 'RUNNING', 'AWAITING_APPROVAL'];

  it('counts nothing for a rollout with no steps', () => {
    expect(rolloutProgress([])).toEqual({ completed: 0, total: 0 });
    expect(rolloutProgress(undefined)).toEqual({ completed: 0, total: 0 });
  });

  it.each(finished)('counts a %s step as completed', (state) => {
    expect(rolloutProgress([deploy('prod', state)])).toEqual({ completed: 1, total: 1 });
  });

  it.each(running)('does not count a %s step as completed', (state) => {
    expect(rolloutProgress([deploy('prod', state)])).toEqual({ completed: 0, total: 1 });
  });

  it('counts the steps inside a stage rather than the stage itself', () => {
    const steps = [
      stage('dev', [deploy('dev-eu', 'SUCCESS')], 'SUCCESS'),
      stage('prod', [deploy('prod-eu', 'SUCCESS'), deploy('prod-us', 'PENDING')], 'RUNNING'),
    ];

    expect(rolloutProgress(steps)).toEqual({ completed: 2, total: 3 });
  });

  it('counts bare steps alongside nested ones', () => {
    const steps = [
      stage('dev', [deploy('dev-eu', 'SUCCESS')], 'SUCCESS'),
      deploy('prod', 'PENDING'),
    ];

    expect(rolloutProgress(steps)).toEqual({ completed: 1, total: 2 });
  });
});
