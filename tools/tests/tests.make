
TEST_CS_EXE_SRCS = \
	arraypadding.cs \
	marshalansi.cs \
	mixedmode-call.cs \
	mixedmode-exe.cs \
	mixedmode-managedcaller.cs \
	mixedmode-nativedir.cs \
	mixedmode-path.cs \
	mixedmode-samedir.cs \
	ordinalimport.cs \
	privatepath1.cs \
	privatepath2.cs \
	processnames.cs \
	rcw-visible.cs \
	releasebadptr.cs \
	runtimeinterface.cs \
	vbstartup.cs \
	webbrowsertest.cs \
	wpfclipboard.cs

TEST_RAW_FILES = \
	mixedmode-managedcaller.exe.config \
	privatepath2.exe.config \
	privatepath1.exe.config

TEST_IL_EXE_SRCS = \
	xnatest.il

TEST_CLR_EXE_TARGETS = $(TEST_CS_EXE_SRCS:%.cs=tools/tests/%.exe) $(TEST_IL_EXE_SRCS:%.il=tools/tests/%.exe)

ifeq (1,$(ENABLE_DOTNET_CORE_WPF))
TEST_NUNIT_TARGETS = \
	net_4_x_PresentationCore_test.dll
endif

TEST_INSTALL_FILES = $(TEST_RAW_FILES:%=tools/tests/%)

TEST_BINARY_FILES = \
	mixedmodeexe.exe \
	mixedmodelibrary.dll \
	nativelibrary.dll

tools/tests/%.exe: tools/tests/%.il $(BUILDDIR)/mono-unix/.installed
	$(MONO_ENV) ilasm -target:exe -output:$@ $<

tools/tests/%.exe: tools/tests/%.cs $(BUILDDIR)/mono-unix/.installed
	$(MONO_ENV) csc -unsafe -target:exe -out:$@ $(patsubst %,-r:%,$(filter %.dll,$^)) $(foreach path,$(filter %/.built,$^),-r:$(dir $(path))/$(notdir $(realpath $(dir $(path)))).dll) $< $(shell sed -n '/CSCFLAGS=/s/^.*CSCFLAGS=//p' $<)

tools/tests/%.dll: tools/tests/%.cs $(BUILDDIR)/mono-unix/.installed
	$(MONO_ENV) csc -target:library -out:$@ $(patsubst %,-r:%,$(filter %.dll,$^)) $< $(shell sed -n '/CSCFLAGS=/s/^.*CSCFLAGS=//p' $<)

tools/tests/mixedmode-managedcaller.exe: vstests/Win32/Release/mixedmodelibrary.dll

tools/tests/privatepath1.exe: tools/tests/testcslib1.dll

tools/tests/privatepath2.exe: tools/tests/testcslib1.dll tools/tests/testcslib2.dll

tools/tests/wpfclipboard.exe: $(SRCDIR)/wpf/src/Microsoft.DotNet.Wpf/src/PresentationCore/.built

tools/tests/vbstartup.exe: $(BUILDDIR)/Microsoft.VisualBasic.dll

tools/tests/net_4_x_%_test.dll: $(BUILDDIR)/nunitlite.dll
	$(MONO_ENV) csc -target:library -out:$@ $(patsubst %,-r:%,$(filter %.dll,$^)) $(foreach path,$(filter %/.built,$^),-r:$(dir $(path))/$(notdir $(realpath $(dir $(path)))).dll) $(filter %.cs,$^)

tools/tests/net_4_x_PresentationCore_test.dll: \
	tools/tests/PresentationCore/TextFormatter.cs

TEST_NUNIT_EXTRADEPS_net_4_x_PresentationCore_test.dll = \
	$(SRCDIR)/wpf/src/Microsoft.DotNet.Wpf/src/WindowsBase/.built \
	$(SRCDIR)/wpf/src/Microsoft.DotNet.Wpf/src/PresentationCore/.built

define nunit_target_template
tools/tests/$(1): $$(TEST_NUNIT_EXTRADEPS_$(1))
$$(TESTS_OUTDIR)/tests-clr/$(1): $$(SRCDIR)/tools/tests/$(1) tests-clr
	mkdir -p $$(TESTS_OUTDIR)/tests-clr
	$$(MONO_ENV) MONO_PATH=$$(subst $$(eval) ,:,$$(foreach path,$$(TEST_NUNIT_EXTRADEPS_$(1)),$$(dir $$(path)))) mono $(TESTS_OUTDIR)/tests-clr/nunit-lite-console.exe $$< -explore:$$(TESTS_OUTDIR)/tests-clr/$(1).testlist && test -f $$(TESTS_OUTDIR)/tests-clr/$(1).testlist
	cp $$< $$@
tests: $$(TESTS_OUTDIR)/tests-clr/$(1)
endef

$(foreach target,$(TEST_NUNIT_TARGETS), $(eval $(call nunit_target_template,$(target))))

tools-tests-all: $(TEST_CLR_EXE_TARGETS) $(TEST_INSTALL_FILES) tools/tests/tests.make
.PHONY: tools-tests-all

tools-tests-install: tools-tests-all $(BUILDDIR)/fixupclr.exe $(BUILDDIR)/call-mixedmode-x86.exe $(BUILDDIR)/call-mixedmode-x86_64.exe
	mkdir -p $(TESTS_OUTDIR)/tests-x86
	mkdir -p $(TESTS_OUTDIR)/tests-x86_64
	for i in $(TEST_CLR_EXE_TARGETS); do \
		cp $$i $(TESTS_OUTDIR)/tests-x86 ; \
		$(WINE) $(BUILDDIR)/fixupclr.exe x86 $(TESTS_OUTDIR)/tests-x86/$$(basename $$i) ; \
		cp $$i $(TESTS_OUTDIR)/tests-x86_64 ; \
		$(WINE) $(BUILDDIR)/fixupclr.exe x86_64 $(TESTS_OUTDIR)/tests-x86_64/$$(basename $$i) ; \
	done
	for i in $(TEST_INSTALL_FILES); do \
		cp $$i $(TESTS_OUTDIR)/tests-x86 ; \
		cp $$i $(TESTS_OUTDIR)/tests-x86_64 ; \
	done
	mkdir -p $(TESTS_OUTDIR)/tests-x86/lib1
	cp tools/tests/testcslib1.dll $(TESTS_OUTDIR)/tests-x86/lib1
	mkdir -p $(TESTS_OUTDIR)/tests-x86_64/lib1
	cp tools/tests/testcslib1.dll $(TESTS_OUTDIR)/tests-x86_64/lib1
	mkdir -p $(TESTS_OUTDIR)/tests-x86/lib2
	cp tools/tests/testcslib2.dll $(TESTS_OUTDIR)/tests-x86/lib2
	mkdir -p $(TESTS_OUTDIR)/tests-x86_64/lib2
	cp tools/tests/testcslib2.dll $(TESTS_OUTDIR)/tests-x86_64/lib2
	mkdir -p $(TESTS_OUTDIR)/tests-x86/vstests
	mkdir -p $(TESTS_OUTDIR)/tests-x86_64/vstests
	for i in $(TEST_BINARY_FILES); do \
		cp $(SRCDIR)/vstests/Win32/Release/$$i $(TESTS_OUTDIR)/tests-x86/vstests ; \
		cp $(SRCDIR)/vstests/x64/Release/$$i $(TESTS_OUTDIR)/tests-x86_64/vstests ; \
	done
	cp tools/tests/mixedmode-managedcaller.exe $(TESTS_OUTDIR)/tests-x86/vstests
	$(WINE) $(BUILDDIR)/fixupclr.exe x86 $(TESTS_OUTDIR)/tests-x86/vstests/mixedmode-managedcaller.exe
	$(INSTALL_PE_x86) $(BUILDDIR)/call-mixedmode-x86.exe $(TESTS_OUTDIR)/tests-x86/vstests/call-mixedmode.exe
	cp tools/tests/mixedmode-managedcaller.exe $(TESTS_OUTDIR)/tests-x86_64/vstests
	$(WINE) $(BUILDDIR)/fixupclr.exe x86_64 $(TESTS_OUTDIR)/tests-x86_64/vstests/mixedmode-managedcaller.exe
	$(INSTALL_PE_x86_64) $(BUILDDIR)/call-mixedmode-x86_64.exe $(TESTS_OUTDIR)/tests-x86_64/vstests/call-mixedmode.exe
	mkdir -p $(TESTS_OUTDIR)/tests-x86/vstests-native
	cp tools/tests/mixedmode-managedcaller.exe vstests/Win32/Release/nativelibrary.dll $(TESTS_OUTDIR)/tests-x86/vstests-native
	cp tools/tests/mixedmode-managedcaller-nativedir.exe.config $(TESTS_OUTDIR)/tests-x86/vstests-native/mixedmode-managedcaller.exe.config
	$(WINE) $(BUILDDIR)/fixupclr.exe x86 $(TESTS_OUTDIR)/tests-x86/vstests-native/mixedmode-managedcaller.exe
	mkdir -p $(TESTS_OUTDIR)/tests-x86_64/vstests-native
	cp tools/tests/mixedmode-managedcaller.exe vstests/x64/Release/nativelibrary.dll $(TESTS_OUTDIR)/tests-x86_64/vstests-native
	cp tools/tests/mixedmode-managedcaller-nativedir.exe.config $(TESTS_OUTDIR)/tests-x86_64/vstests-native/mixedmode-managedcaller.exe.config
	$(WINE) $(BUILDDIR)/fixupclr.exe x86_64 $(TESTS_OUTDIR)/tests-x86_64/vstests-native/mixedmode-managedcaller.exe
	mkdir -p $(TESTS_OUTDIR)/tests-x86/vstests-native/vstests-mixed
	cp vstests/Win32/Release/mixedmodelibrary.dll $(TESTS_OUTDIR)/tests-x86/vstests-native/vstests-mixed
	mkdir -p $(TESTS_OUTDIR)/tests-x86_64/vstests-native/vstests-mixed
	cp vstests/x64/Release/mixedmodelibrary.dll $(TESTS_OUTDIR)/tests-x86_64/vstests-native/vstests-mixed
.PHONY: tools-tests-install

tests: tools-tests-install

clean-tools-tests:
	rm -f $(SRCDIR)/tools/tests/*.dll $(SRCDIR)/tools/tests/*.exe
.PHONY: clean-tools-tests
clean: clean-tools-tests

define MINGW_TEMPLATE +=

$$(BUILDDIR)/call-mixedmode-$(1).exe: $$(SRCDIR)/tools/tests/call-mixedmode.c $$(MINGW_DEPS)
	$$(MINGW_ENV) $$(MINGW_$(1))-gcc $$(filter %.lib,$$^) $$< -o $$@

clean-call-mixedmode-$(1):
	rm -f $$(BUILDDIR)/call-mixedmode-$(1).exe
.PHONY: clean-call-mixedmode-$(1)
clean-build: clean-call-mixedmode-$(1)

endef

$(BUILDDIR)/call-mixedmode-x86.exe: $(SRCDIR)/vstests/Win32/Release/mixedmodelibrary.lib

$(BUILDDIR)/call-mixedmode-x86_64.exe: $(SRCDIR)/vstests/x64/Release/mixedmodelibrary.lib
