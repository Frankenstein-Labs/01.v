import { EXTENSION_ICONS } from '~/vue_merge_request_widget/constants';
import {
  parseDependencies,
  getSummaryTextWithReportItems,
  groupLicensesByStatus,
  createLicenseSections,
  transformLicense,
} from 'ee/vue_merge_request_widget/widgets/license_compliance/utils';
import { licenses } from './mock_data';

describe('parseDependencies', () => {
  it('generates a string', () => {
    expect(parseDependencies(licenses[1].dependencies)).toBe(
      'websocket-driver, websocket-extensions, xml-name-validator',
    );
  });
});

describe('getSummaryTextWithReportItems', () => {
  const baseParams = {
    hasBaseReportLicenses: false,
    hasDeniedLicense: false,
    hasApprovalRequired: false,
    licenseReportCount: 1,
  };

  it.each`
    scenario                           | params                                                                                | expected
    ${'approval required with base'}   | ${{ hasBaseReportLicenses: true, hasDeniedLicense: true, hasApprovalRequired: true }} | ${'License compliance detected 1 new license and policy violation; approval required'}
    ${'approval required source only'} | ${{ hasDeniedLicense: true, hasApprovalRequired: true }}                              | ${'License compliance detected 1 license and policy violation for the source branch only; approval required'}
    ${'violation with base'}           | ${{ hasBaseReportLicenses: true, hasDeniedLicense: true }}                            | ${'License compliance detected 1 new license and policy violation'}
    ${'violation source only'}         | ${{ hasDeniedLicense: true }}                                                         | ${'License compliance detected 1 license and policy violation for the source branch only'}
    ${'new license with base'}         | ${{ hasBaseReportLicenses: true }}                                                    | ${'License compliance detected 1 new license'}
    ${'source only no violations'}     | ${{}}                                                                                 | ${'License compliance detected 1 license for the source branch only'}
    ${'plural counts'}                 | ${{ hasBaseReportLicenses: true, licenseReportCount: 3 }}                             | ${'License compliance detected 3 new licenses'}
  `('returns $scenario', ({ params, expected }) => {
    const result = getSummaryTextWithReportItems({
      ...baseParams,
      ...params,
    });

    expect(result).toBe(expected);
  });
});

describe('groupLicensesByStatus', () => {
  it('returns empty object for empty array', () => {
    expect(groupLicensesByStatus([])).toEqual({});
  });

  it('groups licenses by status', () => {
    const unclassifiedLicense = { status: 'unclassified', link: { text: 'LGPL-2.1' } };
    const unclassifiedLicense2 = { status: 'unclassified', link: { text: 'MIT License' } };
    const deniedLicense = { status: 'denied', link: { text: 'GPL-3.0' } };

    const input = [unclassifiedLicense, unclassifiedLicense2, deniedLicense];

    expect(groupLicensesByStatus(input)).toEqual({
      unclassified: [unclassifiedLicense, unclassifiedLicense2],
      denied: [deniedLicense],
    });
  });
});

describe('createLicenseSections', () => {
  it('returns empty array for empty grouped licenses', () => {
    expect(createLicenseSections({})).toEqual([]);
  });

  it('creates sections in order: denied, unclassified, allowed', () => {
    const groupedLicenses = {
      allowed: [{ status: 'allowed', link: { text: 'MIT License' } }],
      denied: [{ status: 'denied', link: { text: 'GPL-3.0' } }],
      unclassified: [{ status: 'unclassified', link: { text: 'LGPL-2.1' } }],
    };

    expect(createLicenseSections(groupedLicenses)).toMatchObject([
      { header: 'Denied', children: groupedLicenses.denied },
      { header: 'Uncategorized', children: groupedLicenses.unclassified },
      { header: 'Allowed', children: groupedLicenses.allowed },
    ]);
  });

  it('excludes empty groups', () => {
    const groupedLicenses = {
      unclassified: [{ status: 'unclassified', link: { text: 'LGPL-2.1' } }],
    };

    const result = createLicenseSections(groupedLicenses);

    expect(result).toHaveLength(1);
    expect(result[0].header).toBe('Uncategorized');
  });
});

describe('transformLicense', () => {
  const fullReportPath = '/project/-/licenses';
  const createLicense = (overrides = {}) => ({
    name: 'MIT License',
    url: 'https://spdx.org/licenses/MIT.html',
    dependencies: [{ name: 'lodash' }],
    classification: { approval_status: 'unclassified' },
    ...overrides,
  });

  it('transforms unclassified license with actions', () => {
    const license = createLicense({
      dependencies: [{ name: 'lodash' }, { name: 'readline-sync' }],
    });

    expect(transformLicense(license, fullReportPath)).toMatchObject({
      status: license.classification.approval_status,
      icon: { name: EXTENSION_ICONS.notice },
      link: { href: license.url, text: license.name },
      actions: [{ text: 'Used by 2 packages', href: fullReportPath }],
    });
  });

  it('transforms allowed license with actions', () => {
    const license = createLicense({
      classification: { approval_status: 'allowed' },
    });

    expect(transformLicense(license, fullReportPath)).toMatchObject({
      status: license.classification.approval_status,
      icon: { name: EXTENSION_ICONS.success },
      link: { href: license.url, text: license.name },
      actions: [{ text: 'Used by 1 package', href: fullReportPath }],
    });
  });

  it('transforms denied license with supportingText', () => {
    const license = createLicense({
      dependencies: [{ name: 'some-gpl-package' }],
      classification: { approval_status: 'denied' },
    });

    expect(transformLicense(license, fullReportPath)).toMatchObject({
      status: license.classification.approval_status,
      icon: { name: EXTENSION_ICONS.failed },
      link: { href: license.url, text: license.name },
      supportingText: ` Used by ${license.dependencies[0].name}`,
    });
  });

  it('transforms denied license with no dependencies', () => {
    const license = createLicense({
      dependencies: [],
      classification: { approval_status: 'denied' },
    });

    expect(transformLicense(license, fullReportPath)).toMatchObject({
      status: license.classification.approval_status,
      supportingText: '',
    });
  });
});
