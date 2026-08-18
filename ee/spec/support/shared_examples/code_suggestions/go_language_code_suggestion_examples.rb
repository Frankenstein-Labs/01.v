# frozen_string_literal: true

RSpec.shared_examples 'go language' do
  using RSpec::Parameterized::TableSyntax

  let(:language_name) { 'Go' }

  subject do
    described_class.new(language_name).cursor_inside_empty_function?(content_above_cursor, content_below_cursor)
  end

  context 'when various variations of empty functions are used' do
    where(example: [
      <<~EXAMPLE,
        func TestCheckOK(t *testing.T) {
          <CURSOR>

        func TestCheckBadCreds(t *testing.T) {
          defer cleanup()
        }

        func TestCheckBadCreds2() error {
          defer cleanup()
        }
      EXAMPLE

      <<~EXAMPLE,
        func TestCheckBadCreds2() error {
          defer cleanup()
        }

        func HealthCheckDialer(base Dialer) Dialer {
          <CURSOR>
        }

        type DNSResolverBuilderConfig dnsresolver.BuilderConfig

        func Dial(rawAddress string, connOpts []grpc.DialOption) (*grpc.ClientConn, error) {
          return DialContext(context.Background(), rawAddress, connOpts)
        }
      EXAMPLE

      <<~EXAMPLE,
        func DefaultDNSResolverBuilderConfig() *DNSResolverBuilderConfig {


          <CURSOR>

        func HealthCheckDialer(base Dialer) Dialer {
          return Dialer()
        }

        func TestCheckBadCreds2() error {
          defer cleanup()
        }
      EXAMPLE

      <<~EXAMPLE,
        package client

        import (
          "context"
          "io"
        )

        func DialContext(ctx context.Context, connOpts []grpc.DialOption) (*grpc.ClientConn, error) {
          <CURSOR>
        }
      EXAMPLE

      <<~EXAMPLE,
        func TestCheckBadCreds(t *testing.T) {
          defer cleanup()
        }

        func TestCheckOK(t *testing.T) {
          <CURSOR>
      EXAMPLE

      <<~EXAMPLE,
        func someFunc() {<CURSOR>}
      EXAMPLE

      <<~EXAMPLE,
        func someFuncWithArgs(a int, b string) {<CURSOR>}
      EXAMPLE

      <<~EXAMPLE,
        func someFuncWithVariadicArgs(a int, b ...string) {<CURSOR>}
      EXAMPLE

      <<~EXAMPLE,
        func someFuncWithReturnArg() int {
          <CURSOR>
        }
      EXAMPLE

      <<~EXAMPLE,
        func someFuncWithReturnArgs() (int, string) {
          <CURSOR>
        }
      EXAMPLE

      <<~EXAMPLE,
        func someFuncWithNamedReturnArgs() (a int, b string) {
          <CURSOR>
        }
      EXAMPLE

      <<~EXAMPLE,
        func (s SomeStruct) someMethod() {<CURSOR>}
      EXAMPLE

      <<~EXAMPLE,
        func (s SomeStruct) someMethodWithArgs(a int, b string) {<CURSOR>}
      EXAMPLE

      <<~EXAMPLE,
        func (s SomeStruct) someMethodWithVariadicArgs(a int, b ...string) {<CURSOR>}
      EXAMPLE

      <<~EXAMPLE,
        func (s SomeStruct) someMethodWithReturnArg() int {
          <CURSOR>
        }
      EXAMPLE

      <<~EXAMPLE,
        func (s SomeStruct) someMethodWithReturnArgs() (int, string) {
          <CURSOR>
        }
      EXAMPLE

      <<~EXAMPLE,
        func (s SomeStruct) someMethodWithNamedReturnArgs() (a int, b string) {
          <CURSOR>
        }
      EXAMPLE

      <<~EXAMPLE,
        func (s *SomeStruct) someMethod() {<CURSOR>}
      EXAMPLE

      <<~EXAMPLE,
        func (s *SomeStruct) someMethodWithArgs(a *int, b *string) {<CURSOR>}
      EXAMPLE

      <<~EXAMPLE,
        func (s *SomeStruct) someMethodWithReturnArgs() (*int, *string) {
          <CURSOR>
        }
      EXAMPLE

      <<~EXAMPLE,
        func (s *SomeStruct) someMethodWithNamedReturnArgs() (a *int, b *string) {
          <CURSOR>
        }
      EXAMPLE

      <<~EXAMPLE,
        func() {<CURSOR>}
      EXAMPLE

      <<~EXAMPLE,
        anonymous := func() {<CURSOR>}
      EXAMPLE

      <<~EXAMPLE,
       func() {}(<CURSOR>)
      EXAMPLE

      <<~EXAMPLE,
        go func() {<CURSOR>}
      EXAMPLE

      <<~EXAMPLE,
       go func() {<CURSOR>}()
      EXAMPLE

      <<~EXAMPLE
       go func(a int, b string) {<CURSOR>}(0, "")
      EXAMPLE
    ])

    with_them do
      let(:content_above_cursor) { example.split("<CURSOR>").first }
      let(:content_below_cursor) { example.split("<CURSOR>").last }

      it { is_expected.to be_truthy }
    end
  end

  context 'when cursor is inside a non-empty method' do
    let(:example) do
      <<~CONTENT
        func TestCheckOK(t *testing.T) {
          <CURSOR>
          defer cleanup()
        }

        func TestCheckBadCreds2() error {
          defer cleanup()
        }
      CONTENT
    end

    let(:content_above_cursor) { example.split("<CURSOR>").first }
    let(:content_below_cursor) { example.split("<CURSOR>").last }

    it { is_expected.to be_falsey }
  end

  context 'when cursor is outside an empty method' do
    let(:example) do
      <<~CONTENT
        func TestCheckBadCreds2() error {
          defer cleanup()
        }

        func HealthCheckDialer(base Dialer) Dialer {
          // This is a doc string in GoLang
        }

        <CURSOR>
      CONTENT
    end

    let(:content_above_cursor) { example.split("<CURSOR>").first }
    let(:content_below_cursor) { example.split("<CURSOR>").last }

    it { is_expected.to be_falsey }
  end

  context 'when language is different that the given' do
    let(:example) do
      <<~CONTENT
        def index4(arg1, arg2):
          return 1

        def func1():
          <CURSOR>

        def index2():
          return 0

        def index3(arg1):
          return 1
      CONTENT
    end

    let(:content_above_cursor) { example.split("<CURSOR>").first }
    let(:content_below_cursor) { example.split("<CURSOR>").last }

    it { is_expected.to be_falsey }
  end
end
