#!/usr/bin/env python3
"""Generate SalaryTrain.xcodeproj with two targets: Tool + macOS App."""
import pathlib

SRC = pathlib.Path(__file__).parent.resolve()
XCP = SRC / "SalaryTrain.xcodeproj"
WS  = XCP / "project.xcworkspace"
SC  = XCP / "xcshareddata" / "xcschemes"

# ── Deterministic UUIDs ─────────────────────────────────────
U = dict(
    # file references (products)
    prodToolRef      = "88B000000000000000000001",  # SalaryTrain binary
    prodAppRef       = "88B000000000000000000002",  # SalaryTrainApp.app
    # file system synchronized groups
    sourcesGroup     = "88B000000000000000000003",  # Sources/ (12 .swift)
    launcherGroup    = "88B000000000000000000004",  # Launcher/ (1 .swift)
    assetsGroup      = "88B000000000000000000005",  # Assets/ (cat.gif + .icns)
    # groups
    rootGroup        = "88B000000000000000000010",
    productsGroup    = "88B000000000000000000011",
    # build phases – Target 1 (Tool)
    srcPhase1        = "88B000000000000000000020",
    fwkPhase1        = "88B000000000000000000021",
    # build phases – Target 2 (App)
    srcPhase2        = "88B000000000000000000022",
    fwkPhase2        = "88B000000000000000000023",
    resPhase2        = "88B000000000000000000024",
    copyPhase2       = "88B000000000000000000025",
    # build files (explicit)
    buildFileBinary  = "88B000000000000000000030",
    # targets
    targetTool       = "88B000000000000000000040",
    targetApp        = "88B000000000000000000041",
    # dependency
    containerProxy   = "88B000000000000000000050",
    targetDependency = "88B000000000000000000051",
    # project
    project          = "88B000000000000000000060",
    # config lists
    cclProj          = "88B000000000000000000070",
    cclTool          = "88B000000000000000000071",
    cclApp           = "88B000000000000000000072",
    # build configs – project
    cfgProjDebug     = "88B000000000000000000080",
    cfgProjRelease   = "88B000000000000000000081",
    # build configs – Tool target
    cfgToolDebug     = "88B000000000000000000082",
    cfgToolRelease   = "88B000000000000000000083",
    # build configs – App target
    cfgAppDebug      = "88B000000000000000000084",
    cfgAppRelease    = "88B000000000000000000085",
)

P = lambda *a: f"/* {' '.join(a)} */"

# ── Shared project-level build settings ──────────────────────
PROJ_BASE = """
ALWAYS_SEARCH_USER_PATHS = NO;
CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
CLANG_ENABLE_MODULES = YES;
CLANG_ENABLE_OBJC_ARC = YES;
CLANG_ENABLE_OBJC_WEAK = YES;
COPY_PHASE_STRIP = NO;
DEBUG_INFORMATION_FORMAT = dwarf;
GCC_C_LANGUAGE_STANDARD = gnu17;
GCC_DYNAMIC_NO_PIC = NO;
GCC_NO_COMMON_BLOCKS = YES;
GCC_OPTIMIZATION_LEVEL = 0;
GCC_PREPROCESSOR_DEFINITIONS = ("DEBUG=1", "$(inherited)");
MACOSX_DEPLOYMENT_TARGET = 14.0;
SDKROOT = macosx;
SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";
SWIFT_OPTIMIZATION_LEVEL = "-Onone";
SWIFT_VERSION = 5.0;
"""

PROJ_REL = """
ALWAYS_SEARCH_USER_PATHS = NO;
CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
CLANG_ENABLE_MODULES = YES;
CLANG_ENABLE_OBJC_ARC = YES;
CLANG_ENABLE_OBJC_WEAK = YES;
COPY_PHASE_STRIP = NO;
DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
ENABLE_NS_ASSERTIONS = NO;
GCC_C_LANGUAGE_STANDARD = gnu17;
GCC_NO_COMMON_BLOCKS = YES;
MACOSX_DEPLOYMENT_TARGET = 14.0;
SDKROOT = macosx;
SWIFT_COMPILATION_MODE = wholemodule;
SWIFT_VERSION = 5.0;
"""

TGT_DEBUG = """
CODE_SIGN_STYLE = Automatic;
ENABLE_HARDENED_RUNTIME = YES;
ENABLE_USER_SCRIPT_SANDBOXING = NO;
MACOSX_DEPLOYMENT_TARGET = 14.0;
PRODUCT_NAME = "$(TARGET_NAME)";
SWIFT_VERSION = 5.0;
"""

TGT_REL = """
CODE_SIGN_STYLE = Automatic;
ENABLE_HARDENED_RUNTIME = YES;
ENABLE_USER_SCRIPT_SANDBOXING = NO;
MACOSX_DEPLOYMENT_TARGET = 14.0;
PRODUCT_NAME = "$(TARGET_NAME)";
SWIFT_VERSION = 5.0;
"""

APP_DEBUG = """
CODE_SIGN_STYLE = Automatic;
ENABLE_HARDENED_RUNTIME = YES;
ENABLE_USER_SCRIPT_SANDBOXING = NO;
INFOPLIST_FILE = Info.plist;
MACOSX_DEPLOYMENT_TARGET = 14.0;
PRODUCT_BUNDLE_IDENTIFIER = com.lemonade.SalaryTrain;
PRODUCT_NAME = "$(TARGET_NAME)";
SWIFT_VERSION = 5.0;
"""

APP_REL = """
CODE_SIGN_STYLE = Automatic;
ENABLE_HARDENED_RUNTIME = YES;
ENABLE_USER_SCRIPT_SANDBOXING = NO;
INFOPLIST_FILE = Info.plist;
MACOSX_DEPLOYMENT_TARGET = 14.0;
PRODUCT_BUNDLE_IDENTIFIER = com.lemonade.SalaryTrain;
PRODUCT_NAME = "$(TARGET_NAME)";
SWIFT_VERSION = 5.0;
"""

# ── .pbxproj ────────────────────────────────────────────────
pbxproj = f"""\
// !$*UTF8*$!
{{
\tarchiveVersion = 1;
\tclasses = {{
\t}};
\tobjectVersion = 77;
\tobjects = {{

/* Begin PBXBuildFile section */
\t\t{U['buildFileBinary']} {P('SalaryTrain in CopyFiles')} = {{
\t\t\tisa = PBXBuildFile;
\t\t\tfileRef = {U['prodToolRef']} {P('SalaryTrain')};
\t\t}};
/* End PBXBuildFile section */

/* Begin PBXContainerItemProxy section */
\t\t{U['containerProxy']} {P('PBXContainerItemProxy')} = {{
\t\t\tisa = PBXContainerItemProxy;
\t\t\tcontainerPortal = {U['project']} {P('Project object')};
\t\t\tproxyType = 1;
\t\t\tremoteGlobalIDString = {U['targetTool']};
\t\t\tremoteInfo = SalaryTrain;
\t\t}};
/* End PBXContainerItemProxy section */

/* Begin PBXCopyFilesBuildPhase section */
\t\t{U['copyPhase2']} {P('Copy SalaryTrain Binary')} = {{
\t\t\tisa = PBXCopyFilesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tdstPath = "";
\t\t\tdstSubfolderSpec = 7;
\t\t\tfiles = (
\t\t\t\t{U['buildFileBinary']} {P('SalaryTrain in CopyFiles')},
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXCopyFilesBuildPhase section */

/* Begin PBXFileReference section */
\t\t{U['prodToolRef']} {P('SalaryTrain')} = {{
\t\t\tisa = PBXFileReference;
\t\t\texplicitFileType = "compiled.mach-o.executable";
\t\t\tincludeInIndex = 0;
\t\t\tpath = SalaryTrain;
\t\t\tsourceTree = BUILT_PRODUCTS_DIR;
\t\t}};
\t\t{U['prodAppRef']} {P('SalaryTrainApp.app')} = {{
\t\t\tisa = PBXFileReference;
\t\t\texplicitFileType = wrapper.application;
\t\t\tincludeInIndex = 0;
\t\t\tpath = SalaryTrainApp.app;
\t\t\tsourceTree = BUILT_PRODUCTS_DIR;
\t\t}};
/* End PBXFileReference section */

/* Begin PBXFileSystemSynchronizedRootGroup section */
\t\t{U['sourcesGroup']} {P('Sources')} = {{
\t\t\tisa = PBXFileSystemSynchronizedRootGroup;
\t\t\tpath = Sources;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{U['launcherGroup']} {P('Launcher')} = {{
\t\t\tisa = PBXFileSystemSynchronizedRootGroup;
\t\t\tpath = Launcher;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{U['assetsGroup']} {P('Assets')} = {{
\t\t\tisa = PBXFileSystemSynchronizedRootGroup;
\t\t\tpath = Assets;
\t\t\tsourceTree = "<group>";
\t\t}};
/* End PBXFileSystemSynchronizedRootGroup section */

/* Begin PBXFrameworksBuildPhase section */
\t\t{U['fwkPhase1']} {P('Frameworks')} = {{
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
\t\t{U['fwkPhase2']} {P('Frameworks')} = {{
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
\t\t{U['rootGroup']} = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{U['sourcesGroup']} {P('Sources')},
\t\t\t\t{U['launcherGroup']} {P('Launcher')},
\t\t\t\t{U['assetsGroup']} {P('Assets')},
\t\t\t\t{U['productsGroup']} {P('Products')},
\t\t\t);
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{U['productsGroup']} {P('Products')} = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{U['prodToolRef']} {P('SalaryTrain')},
\t\t\t\t{U['prodAppRef']} {P('SalaryTrainApp.app')},
\t\t\t);
\t\t\tname = Products;
\t\t\tsourceTree = "<group>";
\t\t}};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
\t\t{U['targetTool']} {P('SalaryTrain')} = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {U['cclTool']} {P('Build config list for PBXNativeTarget "SalaryTrain"')};
\t\t\tbuildPhases = (
\t\t\t\t{U['srcPhase1']} {P('Sources')},
\t\t\t\t{U['fwkPhase1']} {P('Frameworks')},
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tfileSystemSynchronizedGroups = (
\t\t\t\t{U['sourcesGroup']} {P('Sources')},
\t\t\t);
\t\t\tname = SalaryTrain;
\t\t\tproductName = SalaryTrain;
\t\t\tproductReference = {U['prodToolRef']} {P('SalaryTrain')};
\t\t\tproductType = "com.apple.product-type.tool";
\t\t}};
\t\t{U['targetApp']} {P('SalaryTrainApp')} = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {U['cclApp']} {P('Build config list for PBXNativeTarget "SalaryTrainApp"')};
\t\t\tbuildPhases = (
\t\t\t\t{U['srcPhase2']} {P('Sources')},
\t\t\t\t{U['fwkPhase2']} {P('Frameworks')},
\t\t\t\t{U['resPhase2']} {P('Resources')},
\t\t\t\t{U['copyPhase2']} {P('Copy SalaryTrain Binary')},
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t\t{U['targetDependency']} {P('SalaryTrain Dependency')},
\t\t\t);
\t\t\tfileSystemSynchronizedGroups = (
\t\t\t\t{U['launcherGroup']} {P('Launcher')},
\t\t\t\t{U['assetsGroup']} {P('Assets')},
\t\t\t);
\t\t\tname = SalaryTrainApp;
\t\t\tpackageProductDependencies = (
\t\t\t);
\t\t\tproductName = SalaryTrainApp;
\t\t\tproductReference = {U['prodAppRef']} {P('SalaryTrainApp.app')};
\t\t\tproductType = "com.apple.product-type.application";
\t\t}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
\t\t{U['project']} {P('Project object')} = {{
\t\t\tisa = PBXProject;
\t\t\tattributes = {{
\t\t\t\tBuildIndependentTargetsInParallel = 1;
\t\t\t\tLastSwiftUpdateCheck = 1620;
\t\t\t\tLastUpgradeCheck = 1620;
\t\t\t\tTargetAttributes = {{
\t\t\t\t\t{U['targetTool']} = {{
\t\t\t\t\t\tCreatedOnToolsVersion = 16.2;
\t\t\t\t\t}};
\t\t\t\t\t{U['targetApp']} = {{
\t\t\t\t\t\tCreatedOnToolsVersion = 16.2;
\t\t\t\t\t}};
\t\t\t\t}};
\t\t\t}};
\t\t\tbuildConfigurationList = {U['cclProj']} {P('Build config list for PBXProject "SalaryTrain"')};
\t\t\tdevelopmentRegion = en;
\t\t\thasScannedForEncodings = 0;
\t\t\tknownRegions = (
\t\t\t\ten,
\t\t\t\tBase,
\t\t\t);
\t\t\tmainGroup = {U['rootGroup']};
\t\t\tminimizedProjectReferenceProxies = 1;
\t\t\tpreferredProjectObjectVersion = 77;
\t\t\tproductRefGroup = {U['productsGroup']} {P('Products')};
\t\t\tprojectDirPath = "";
\t\t\tprojectRoot = "";
\t\t\ttargets = (
\t\t\t\t{U['targetTool']} {P('SalaryTrain')},
\t\t\t\t{U['targetApp']} {P('SalaryTrainApp')},
\t\t\t);
\t\t}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
\t\t{U['resPhase2']} {P('Resources')} = {{
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
\t\t{U['srcPhase1']} {P('Sources')} = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
\t\t{U['srcPhase2']} {P('Sources')} = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXSourcesBuildPhase section */

/* Begin PBXTargetDependency section */
\t\t{U['targetDependency']} {P('SalaryTrain Dependency')} = {{
\t\t\tisa = PBXTargetDependency;
\t\t\ttarget = {U['targetTool']} {P('SalaryTrain')};
\t\t\ttargetProxy = {U['containerProxy']} {P('PBXContainerItemProxy')};
\t\t}};
/* End PBXTargetDependency section */

/* Begin XCBuildConfiguration section */
\t\t{U['cfgProjDebug']} {P('Debug')} = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{ {PROJ_BASE}
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{U['cfgProjRelease']} {P('Release')} = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{ {PROJ_REL}
\t\t\t}};
\t\t\tname = Release;
\t\t}};
\t\t{U['cfgToolDebug']} {P('Debug')} = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{ {TGT_DEBUG}
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{U['cfgToolRelease']} {P('Release')} = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{ {TGT_REL}
\t\t\t}};
\t\t\tname = Release;
\t\t}};
\t\t{U['cfgAppDebug']} {P('Debug')} = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{ {APP_DEBUG}
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{U['cfgAppRelease']} {P('Release')} = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{ {APP_REL}
\t\t\t}};
\t\t\tname = Release;
\t\t}};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
\t\t{U['cclProj']} {P('Build config list for PBXProject "SalaryTrain"')} = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{U['cfgProjDebug']} {P('Debug')},
\t\t\t\t{U['cfgProjRelease']} {P('Release')},
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
\t\t{U['cclTool']} {P('Build config list for PBXNativeTarget "SalaryTrain"')} = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{U['cfgToolDebug']} {P('Debug')},
\t\t\t\t{U['cfgToolRelease']} {P('Release')},
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
\t\t{U['cclApp']} {P('Build config list for PBXNativeTarget "SalaryTrainApp"')} = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{U['cfgAppDebug']} {P('Debug')},
\t\t\t\t{U['cfgAppRelease']} {P('Release')},
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
/* End XCConfigurationList section */

\t}};
\trootObject = {U['project']} {P('Project object')};
}}
"""

# ── Workspace ────────────────────────────────────────────────
WORKSPACE_XML = """\
<?xml version="1.0" encoding="UTF-8"?>
<Workspace
   version = "1.0">
   <FileRef
      location = "self:">
   </FileRef>
</Workspace>
"""

# ── Shared Scheme (Target: SalaryTrainApp) ────────────────────
SCHEME_XML = f"""\
<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1620"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{U['targetApp']}"
               BuildableName = "SalaryTrainApp.app"
               BlueprintName = "SalaryTrainApp"
               ReferencedContainer = "container:SalaryTrain.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES"
      shouldAutocreateTestPlan = "YES">
   </TestAction>
   <LaunchAction
      buildConfiguration = "Release"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "NO"
      viewDebuggingEnabled = "NO">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{U['targetApp']}"
            BuildableName = "SalaryTrainApp.app"
            BlueprintName = "SalaryTrainApp"
            ReferencedContainer = "container:SalaryTrain.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{U['targetApp']}"
            BuildableName = "SalaryTrainApp.app"
            BlueprintName = "SalaryTrainApp"
            ReferencedContainer = "container:SalaryTrain.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
"""

# ── Write files ──────────────────────────────────────────────
XCP.mkdir(parents=True, exist_ok=True)
WS.mkdir(parents=True, exist_ok=True)
SC.mkdir(parents=True, exist_ok=True)

(XCP / "project.pbxproj").write_text(pbxproj.strip() + "\n")
(WS  / "contents.xcworkspacedata").write_text(WORKSPACE_XML)
(SC  / "SalaryTrainApp.xcscheme").write_text(SCHEME_XML)

print(f"Generated: {XCP}")
print(f"Open with: open {XCP}")
print(f"Scheme: SalaryTrainApp")
