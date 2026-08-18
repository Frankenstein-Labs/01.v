// To run this spec locally first run `bundle exec rake gitlab:js:routes`

// Instance admin routes are excluded from the organization scope, so these
// helpers always generate unscoped `/admin/*` paths regardless of the current
// organization.
describe('ee/lib/utils/path_helpers/instance_admin', () => {
  const setup = async () => {
    await import('~/behaviors/configure_path_helpers');
  };

  const testCases = [
    {
      pathHelperName: 'identityVerificationExemptionAdminUserPath',
      args: [1, { search: 'foo bar' }],
      baseExpected: '/admin/users/1/identity_verification_exemption?search=foo%20bar',
    },
    {
      pathHelperName: 'adminGeoNodePath',
      args: [1],
      baseExpected: '/admin/geo/sites/1/replication',
    },
  ];

  beforeEach(() => {
    jest.resetModules();
  });

  afterEach(() => {
    window.gon = {};
  });

  describe('with no special configuration', () => {
    beforeEach(async () => {
      await setup();
    });

    it.each(testCases)(
      '$pathHelperName returns $baseExpected',
      async ({ pathHelperName, args, baseExpected }) => {
        const pathHelpers = await import('ee/lib/utils/path_helpers/instance_admin');

        expect(pathHelpers[pathHelperName](...args)).toBe(baseExpected);
      },
    );
  });

  describe('when relative_url_root is set', () => {
    beforeEach(async () => {
      window.gon = { relative_url_root: '/gitlab' };
      await setup();
    });

    it.each(testCases)(
      '$pathHelperName returns /gitlab$baseExpected',
      async ({ pathHelperName, args, baseExpected }) => {
        const pathHelpers = await import('ee/lib/utils/path_helpers/instance_admin');

        expect(pathHelpers[pathHelperName](...args)).toBe(`/gitlab${baseExpected}`);
      },
    );
  });

  describe('when current organization has scoped paths', () => {
    beforeEach(async () => {
      window.gon = {
        current_organization: {
          path: 'acme',
          has_scoped_paths: true,
        },
      };
      await setup();
    });

    it.each(testCases)(
      '$pathHelperName is not affected by organization scoping',
      async ({ pathHelperName, args, baseExpected }) => {
        const pathHelpers = await import('ee/lib/utils/path_helpers/instance_admin');

        expect(pathHelpers[pathHelperName](...args)).toBe(baseExpected);
      },
    );
  });
});
