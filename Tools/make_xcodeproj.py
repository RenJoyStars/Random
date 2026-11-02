#!/usr/bin/env python3
"""
生成 Random.xcodeproj/project.pbxproj

手写 pbxproj 容易在 UUID 上出错，这里用确定性哈希生成 24 位十六进制 ID。
新增源文件后重新运行本脚本即可（或在 Xcode 里直接拖入）。

用法:  python3 Tools/make_xcodeproj.py
"""
import hashlib
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TARGET = "Random"
BUNDLE_ID = "cn.renqiaoyi.random"
DEPLOY_TARGET = "14.0"

SWIFT_FILES = [
    "RandomApp.swift",
    "AppModel.swift",
    "Platform.swift",
    "GlassKit.swift",
    "Sound.swift",
    "ClassRoster.swift",
    "RosterFormat.swift",
    "Speech.swift",
    "Grouping.swift",
    "History.swift",
    "DesignKit.swift",
    "RootView.swift",
    "ClassroomViews.swift",
    "ToolViews.swift",
    "HistoryView.swift",
    "SettingsView.swift",
]
ASSETS = "Assets.xcassets"


def uid(*parts: str) -> str:
    """确定性 24 位十六进制 ID"""
    h = hashlib.sha1("|".join(parts).encode("utf-8")).hexdigest()
    return h[:24].upper()


PROJECT = uid("project", TARGET)
MAIN_GROUP = uid("maingroup")
SRC_GROUP = uid("srcgroup", TARGET)
PRODUCTS_GROUP = uid("products")
TARGET_OBJ = uid("target", TARGET)
PRODUCT_REF = uid("product", TARGET)
SOURCES_PHASE = uid("sources", TARGET)
RESOURCES_PHASE = uid("resources", TARGET)
FRAMEWORKS_PHASE = uid("frameworks", TARGET)
PROJ_CONFIG_LIST = uid("cfglist", "project")
TGT_CONFIG_LIST = uid("cfglist", TARGET)
PROJ_DEBUG = uid("cfg", "project", "debug")
PROJ_RELEASE = uid("cfg", "project", "release")
TGT_DEBUG = uid("cfg", TARGET, "debug")
TGT_RELEASE = uid("cfg", TARGET, "release")


def file_ref(name: str) -> str:
    return uid("fileref", name)


def build_file(name: str) -> str:
    return uid("buildfile", name)


def quoted(s: str) -> str:
    """pbxproj 里含特殊字符的字符串要加引号"""
    if s and all(c.isalnum() or c in "._/$()" for c in s):
        return s
    return '"%s"' % s.replace('"', '\\"')


lines = []
A = lines.append

A("// !$*UTF8*$!")
A("{")
A("\tarchiveVersion = 1;")
A("\tclasses = {")
A("\t};")
A("\tobjectVersion = 56;")
A("\tobjects = {")
A("")

# ---------------- PBXBuildFile ----------------
A("/* Begin PBXBuildFile section */")
for f in SWIFT_FILES:
    A("\t\t%s /* %s in Sources */ = {isa = PBXBuildFile; fileRef = %s /* %s */; };"
      % (build_file(f), f, file_ref(f), f))
A("\t\t%s /* %s in Resources */ = {isa = PBXBuildFile; fileRef = %s /* %s */; };"
  % (build_file(ASSETS), ASSETS, file_ref(ASSETS), ASSETS))
A("/* End PBXBuildFile section */")
A("")

# ---------------- PBXFileReference ----------------
A("/* Begin PBXFileReference section */")
for f in SWIFT_FILES:
    A("\t\t%s /* %s */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; "
      "path = %s; sourceTree = \"<group>\"; };" % (file_ref(f), f, f))
A("\t\t%s /* %s */ = {isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; "
  "path = %s; sourceTree = \"<group>\"; };" % (file_ref(ASSETS), ASSETS, ASSETS))
A("\t\t%s /* %s.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; "
  "includeInIndex = 0; path = %s.app; sourceTree = BUILT_PRODUCTS_DIR; };"
  % (PRODUCT_REF, TARGET, TARGET))
A("/* End PBXFileReference section */")
A("")

# ---------------- PBXFrameworksBuildPhase ----------------
A("/* Begin PBXFrameworksBuildPhase section */")
A("\t\t%s /* Frameworks */ = {" % FRAMEWORKS_PHASE)
A("\t\t\tisa = PBXFrameworksBuildPhase;")
A("\t\t\tbuildActionMask = 2147483647;")
A("\t\t\tfiles = (")
A("\t\t\t);")
A("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
A("\t\t};")
A("/* End PBXFrameworksBuildPhase section */")
A("")

# ---------------- PBXGroup ----------------
A("/* Begin PBXGroup section */")
A("\t\t%s = {" % MAIN_GROUP)
A("\t\t\tisa = PBXGroup;")
A("\t\t\tchildren = (")
A("\t\t\t\t%s /* %s */," % (SRC_GROUP, TARGET))
A("\t\t\t\t%s /* Products */," % PRODUCTS_GROUP)
A("\t\t\t);")
A("\t\t\tsourceTree = \"<group>\";")
A("\t\t};")
A("\t\t%s /* %s */ = {" % (SRC_GROUP, TARGET))
A("\t\t\tisa = PBXGroup;")
A("\t\t\tchildren = (")
for f in SWIFT_FILES:
    A("\t\t\t\t%s /* %s */," % (file_ref(f), f))
A("\t\t\t\t%s /* %s */," % (file_ref(ASSETS), ASSETS))
A("\t\t\t);")
A("\t\t\tpath = %s;" % TARGET)
A("\t\t\tsourceTree = \"<group>\";")
A("\t\t};")
A("\t\t%s /* Products */ = {" % PRODUCTS_GROUP)
A("\t\t\tisa = PBXGroup;")
A("\t\t\tchildren = (")
A("\t\t\t\t%s /* %s.app */," % (PRODUCT_REF, TARGET))
A("\t\t\t);")
A("\t\t\tname = Products;")
A("\t\t\tsourceTree = \"<group>\";")
A("\t\t};")
A("/* End PBXGroup section */")
A("")

# ---------------- PBXNativeTarget ----------------
A("/* Begin PBXNativeTarget section */")
A("\t\t%s /* %s */ = {" % (TARGET_OBJ, TARGET))
A("\t\t\tisa = PBXNativeTarget;")
A("\t\t\tbuildConfigurationList = %s /* Build configuration list for PBXNativeTarget \"%s\" */;"
  % (TGT_CONFIG_LIST, TARGET))
A("\t\t\tbuildPhases = (")
A("\t\t\t\t%s /* Sources */," % SOURCES_PHASE)
A("\t\t\t\t%s /* Frameworks */," % FRAMEWORKS_PHASE)
A("\t\t\t\t%s /* Resources */," % RESOURCES_PHASE)
A("\t\t\t);")
A("\t\t\tbuildRules = (")
A("\t\t\t);")
A("\t\t\tdependencies = (")
A("\t\t\t);")
A("\t\t\tname = %s;" % TARGET)
A("\t\t\tproductName = %s;" % TARGET)
A("\t\t\tproductReference = %s /* %s.app */;" % (PRODUCT_REF, TARGET))
A("\t\t\tproductType = \"com.apple.product-type.application\";")
A("\t\t};")
A("/* End PBXNativeTarget section */")
A("")

# ---------------- PBXProject ----------------
A("/* Begin PBXProject section */")
A("\t\t%s /* Project object */ = {" % PROJECT)
A("\t\t\tisa = PBXProject;")
A("\t\t\tattributes = {")
A("\t\t\t\tBuildIndependentTargetsInParallel = 1;")
A("\t\t\t\tLastSwiftUpdateCheck = 2700;")
A("\t\t\t\tLastUpgradeCheck = 2700;")
A("\t\t\t\tTargetAttributes = {")
A("\t\t\t\t\t%s = {" % TARGET_OBJ)
A("\t\t\t\t\t\tCreatedOnToolsVersion = 27.0;")
A("\t\t\t\t\t};")
A("\t\t\t\t};")
A("\t\t\t};")
A("\t\t\tbuildConfigurationList = %s /* Build configuration list for PBXProject \"%s\" */;"
  % (PROJ_CONFIG_LIST, TARGET))
A("\t\t\tcompatibilityVersion = \"Xcode 14.0\";")
A("\t\t\tdevelopmentRegion = zh-Hans;")
A("\t\t\thasScannedForEncodings = 0;")
A("\t\t\tknownRegions = (")
A("\t\t\t\t\"zh-Hans\",")
A("\t\t\t\tBase,")
A("\t\t\t);")
A("\t\t\tmainGroup = %s;" % MAIN_GROUP)
A("\t\t\tproductRefGroup = %s /* Products */;" % PRODUCTS_GROUP)
A("\t\t\tprojectDirPath = \"\";")
A("\t\t\tprojectRoot = \"\";")
A("\t\t\ttargets = (")
A("\t\t\t\t%s /* %s */," % (TARGET_OBJ, TARGET))
A("\t\t\t);")
A("\t\t};")
A("/* End PBXProject section */")
A("")

# ---------------- PBXResourcesBuildPhase ----------------
A("/* Begin PBXResourcesBuildPhase section */")
A("\t\t%s /* Resources */ = {" % RESOURCES_PHASE)
A("\t\t\tisa = PBXResourcesBuildPhase;")
A("\t\t\tbuildActionMask = 2147483647;")
A("\t\t\tfiles = (")
A("\t\t\t\t%s /* %s in Resources */," % (build_file(ASSETS), ASSETS))
A("\t\t\t);")
A("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
A("\t\t};")
A("/* End PBXResourcesBuildPhase section */")
A("")

# ---------------- PBXSourcesBuildPhase ----------------
A("/* Begin PBXSourcesBuildPhase section */")
A("\t\t%s /* Sources */ = {" % SOURCES_PHASE)
A("\t\t\tisa = PBXSourcesBuildPhase;")
A("\t\t\tbuildActionMask = 2147483647;")
A("\t\t\tfiles = (")
for f in SWIFT_FILES:
    A("\t\t\t\t%s /* %s in Sources */," % (build_file(f), f))
A("\t\t\t);")
A("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
A("\t\t};")
A("/* End PBXSourcesBuildPhase section */")
A("")

# ---------------- XCBuildConfiguration ----------------
COMMON = [
    "ALWAYS_SEARCH_USER_PATHS = NO;",
    "ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;",
    "CLANG_ANALYZER_NONNULL = YES;",
    "CLANG_ENABLE_MODULES = YES;",
    "CLANG_ENABLE_OBJC_ARC = YES;",
    "CLANG_WARN_BOOL_CONVERSION = YES;",
    "CLANG_WARN_DOCUMENTATION_COMMENTS = YES;",
    "CLANG_WARN_EMPTY_BODY = YES;",
    "CLANG_WARN_UNREACHABLE_CODE = YES;",
    "COPY_PHASE_STRIP = NO;",
    "ENABLE_STRICT_OBJC_MSGSEND = YES;",
    "GCC_C_LANGUAGE_STANDARD = gnu17;",
    "GCC_NO_COMMON_BLOCKS = YES;",
    "GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;",
    "GCC_WARN_UNUSED_FUNCTION = YES;",
    "GCC_WARN_UNUSED_VARIABLE = YES;",
    "LOCALIZATION_PREFERS_STRING_CATALOGS = YES;",
    'MACOSX_DEPLOYMENT_TARGET = %s;' % DEPLOY_TARGET,
    "SDKROOT = macosx;",
]

TARGET_COMMON = [
    "ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;",
    "CODE_SIGN_IDENTITY = \"-\";",
    "CODE_SIGN_STYLE = Automatic;",
    "COMBINE_HIDPI_IMAGES = YES;",
    "CURRENT_PROJECT_VERSION = 8;",
    "ENABLE_HARDENED_RUNTIME = YES;",
    "ENABLE_PREVIEWS = YES;",
    "INFOPLIST_FILE = Random/Info.plist;",
    "LD_RUNPATH_SEARCH_PATHS = (",
    "\t\"$(inherited)\",",
    "\t\"@executable_path/../Frameworks\",",
    ");",
    "MARKETING_VERSION = 2.0;",
    # 显式告诉编译器宏插件在哪，让它直接加载插件库；
    # 否则编译器会走 sandbox-exec 启动 swift-plugin-server，部分环境会失败。
    'OTHER_SWIFT_FLAGS = "-plugin-path $(DEVELOPER_DIR)/Platforms/MacOSX.platform/Developer/usr/lib/swift/host/plugins";',
    "PRODUCT_BUNDLE_IDENTIFIER = %s;" % BUNDLE_ID,
    "PRODUCT_NAME = \"$(TARGET_NAME)\";",
    "SWIFT_EMIT_LOC_STRINGS = YES;",
    "SWIFT_VERSION = 5.0;",
]

DEBUG_EXTRA = [
    "DEBUG_INFORMATION_FORMAT = dwarf;",
    "ENABLE_TESTABILITY = YES;",
    "GCC_DYNAMIC_NO_PIC = NO;",
    "GCC_OPTIMIZATION_LEVEL = 0;",
    "GCC_PREPROCESSOR_DEFINITIONS = (",
    "\t\"DEBUG=1\",",
    "\t\"$(inherited)\",",
    ");",
    "MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;",
    "ONLY_ACTIVE_ARCH = YES;",
    "SWIFT_ACTIVE_COMPILATION_CONDITIONS = \"DEBUG $(inherited)\";",
    "SWIFT_OPTIMIZATION_LEVEL = \"-Onone\";",
]

RELEASE_EXTRA = [
    "DEBUG_INFORMATION_FORMAT = \"dwarf-with-dsym\";",
    "ENABLE_NS_ASSERTIONS = NO;",
    "MTL_ENABLE_DEBUG_INFO = NO;",
    "SWIFT_COMPILATION_MODE = wholemodule;",
    "SWIFT_OPTIMIZATION_LEVEL = \"-O\";",
]


def emit_config(cid: str, name: str, extra, target_level: bool):
    A("\t\t%s /* %s */ = {" % (cid, name))
    A("\t\t\tisa = XCBuildConfiguration;")
    A("\t\t\tbuildSettings = {")
    for s in (COMMON + extra if not target_level else TARGET_COMMON + extra):
        A("\t\t\t\t%s" % s)
    A("\t\t\t};")
    A("\t\t\tname = %s;" % name)
    A("\t\t};")


A("/* Begin XCBuildConfiguration section */")
emit_config(PROJ_DEBUG, "Debug", DEBUG_EXTRA, False)
emit_config(PROJ_RELEASE, "Release", RELEASE_EXTRA, False)
emit_config(TGT_DEBUG, "Debug", [], True)
emit_config(TGT_RELEASE, "Release", [], True)
A("/* End XCBuildConfiguration section */")
A("")

# ---------------- XCConfigurationList ----------------
A("/* Begin XCConfigurationList section */")
for lst, label, dbg, rel in (
    (PROJ_CONFIG_LIST, "PBXProject \"%s\"" % TARGET, PROJ_DEBUG, PROJ_RELEASE),
    (TGT_CONFIG_LIST, "PBXNativeTarget \"%s\"" % TARGET, TGT_DEBUG, TGT_RELEASE),
):
    A("\t\t%s /* Build configuration list for %s */ = {" % (lst, label))
    A("\t\t\tisa = XCConfigurationList;")
    A("\t\t\tbuildConfigurations = (")
    A("\t\t\t\t%s /* Debug */," % dbg)
    A("\t\t\t\t%s /* Release */," % rel)
    A("\t\t\t);")
    A("\t\t\tdefaultConfigurationIsVisible = 0;")
    A("\t\t\tdefaultConfigurationName = Release;")
    A("\t\t};")
A("/* End XCConfigurationList section */")
A("")
A("\t};")
A("\trootObject = %s /* Project object */;" % PROJECT)
A("}")
A("")

out_dir = os.path.join(ROOT, "%s.xcodeproj" % TARGET)
os.makedirs(out_dir, exist_ok=True)
out_path = os.path.join(out_dir, "project.pbxproj")
with open(out_path, "w", encoding="utf-8") as fh:
    fh.write("\n".join(lines))

# ---------------- 共享 Scheme ----------------
scheme_dir = os.path.join(out_dir, "xcshareddata", "xcschemes")
os.makedirs(scheme_dir, exist_ok=True)

REF = ('<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="%s" '
       'BuildableName="%s.app" BlueprintName="%s" ReferencedContainer="container:%s.xcodeproj"/>'
       % (TARGET_OBJ, TARGET, TARGET, TARGET))

scheme = """<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2700" version="1.7">
   <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES">
      <BuildActionEntries>
         <BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">
            %(ref)s
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES" shouldAutocreateTestPlan="YES">
      <Testables>
      </Testables>
   </TestAction>
   <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES">
      <BuildableProductRunnable runnableDebuggingMode="0">
         %(ref)s
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES">
      <BuildableProductRunnable runnableDebuggingMode="0">
         %(ref)s
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction buildConfiguration="Debug">
   </AnalyzeAction>
   <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES">
   </ArchiveAction>
</Scheme>
""" % {"ref": REF}

scheme_path = os.path.join(scheme_dir, "%s.xcscheme" % TARGET)
with open(scheme_path, "w", encoding="utf-8") as fh:
    fh.write(scheme)

print("已生成 %s" % scheme_path)
print("已生成 %s (%d 行)" % (out_path, len(lines)))
