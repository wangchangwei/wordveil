#!/usr/bin/env python3
"""Regenerate the small, deterministic Xcode project from checked-in sources."""

from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parent.parent
PROJECT = ROOT / "WordCover.xcodeproj"


def ident(name: str) -> str:
    return hashlib.sha1(name.encode()).hexdigest()[:24].upper()


def q(value: str) -> str:
    return json.dumps(value, ensure_ascii=False)


objects: dict[str, str] = {}


def add(name: str, body: str) -> str:
    key = ident(name)
    objects[key] = body
    return key


def entries(items: list[str]) -> str:
    return "(\n" + "".join(f"\t\t\t\t{item},\n" for item in items) + "\t\t\t)"


source_paths = sorted(
    [
        *[str(p.relative_to(ROOT)) for p in (ROOT / "WordCover").glob("*.swift")],
        *[str(p.relative_to(ROOT)) for p in (ROOT / "OCR").rglob("*.swift")],
        *[str(p.relative_to(ROOT)) for p in (ROOT / "OCR").rglob("*.mm")],
        *[str(p.relative_to(ROOT)) for p in (ROOT / "OCR").rglob("*.cpp")],
    ]
)
headers = sorted(str(p.relative_to(ROOT)) for p in (ROOT / "OCR").rglob("*.h"))
headers += sorted(str(p.relative_to(ROOT)) for p in (ROOT / "OCR").rglob("*.hpp"))
file_refs: dict[str, str] = {}
build_files: list[str] = []
for path in source_paths + headers:
    suffix = Path(path).suffix
    file_type = {
        ".swift": "sourcecode.swift",
        ".mm": "sourcecode.cpp.objcpp",
        ".cpp": "sourcecode.cpp.cpp",
        ".h": "sourcecode.c.h",
        ".hpp": "sourcecode.cpp.h",
    }[suffix]
    file_refs[path] = add(
        "fileref:" + path,
        f"{{isa = PBXFileReference; lastKnownFileType = {file_type}; "
        f"name = {q(Path(path).name)}; path = {q(path)}; sourceTree = SOURCE_ROOT; }}",
    )
    if path in source_paths:
        build_files.append(
            add(
                "build:" + path,
                f"{{isa = PBXBuildFile; fileRef = {file_refs[path]}; }}",
            )
        )

models_ref = add(
    "fileref:models",
    '{isa = PBXFileReference; lastKnownFileType = folder; name = Models; '
    'path = OCR/Models; sourceTree = SOURCE_ROOT; }',
)
models_build = add(
    "build:models", f"{{isa = PBXBuildFile; fileRef = {models_ref}; }}"
)
licenses_ref = add(
    "fileref:licenses",
    '{isa = PBXFileReference; lastKnownFileType = folder; name = Licenses; '
    'path = OCR/Licenses; sourceTree = SOURCE_ROOT; }',
)
licenses_build = add("build:licenses", f"{{isa = PBXBuildFile; fileRef = {licenses_ref}; }}")
asset_catalog_ref = add(
    "fileref:asset-catalog",
    '{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; '
    'name = Assets.xcassets; path = Branding/Wordveil/Assets.xcassets; '
    'sourceTree = SOURCE_ROOT; }',
)
asset_catalog_build = add(
    "build:asset-catalog",
    f"{{isa = PBXBuildFile; fileRef = {asset_catalog_ref}; }}",
)
product_ref = add(
    "fileref:product",
    '{isa = PBXFileReference; explicitFileType = wrapper.application; '
    'includeInIndex = 0; path = WordCover.app; sourceTree = BUILT_PRODUCTS_DIR; }',
)

test_refs = {}
test_products = {}
for name, filename in (("WordCoverTests", "WordCoverTests.swift"), ("WordCoverUITests", "WordCoverUITests.swift")):
    test_refs[name] = add(
        "fileref:" + name,
        f'{{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {q("Tests/" + filename)}; sourceTree = SOURCE_ROOT; }}',
    )
    test_products[name] = add(
        "product:" + name,
        f'{{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = {name}.xctest; sourceTree = BUILT_PRODUCTS_DIR; }}',
    )
fixtures_ref = add(
    "fileref:fixtures",
    '{isa = PBXFileReference; lastKnownFileType = folder; name = Fixtures; path = Tests/Fixtures; sourceTree = SOURCE_ROOT; }',
)
tests_group = add(
    "group:tests",
    f'{{isa = PBXGroup; children = {entries([*test_refs.values(), fixtures_ref])}; name = Tests; sourceTree = "<group>"; }}',
)

localized_info_refs = [
    add(
        "fileref:InfoPlist:" + locale,
        f'{{isa = PBXFileReference; lastKnownFileType = text.plist.strings; name = {q(locale)}; '
        f'path = {q("WordCover/" + locale + ".lproj/InfoPlist.strings")}; sourceTree = SOURCE_ROOT; }}',
    )
    for locale in ("en", "zh-Hans")
]
localized_info = add(
    "variant:InfoPlist",
    f'{{isa = PBXVariantGroup; children = {entries(localized_info_refs)}; name = InfoPlist.strings; sourceTree = "<group>"; }}',
)
localized_info_build = add("build:InfoPlist", f"{{isa = PBXBuildFile; fileRef = {localized_info}; }}")

app_group = add(
    "group:app",
    f"{{isa = PBXGroup; children = {entries([file_refs[p] for p in source_paths if p.startswith('WordCover/')] + [localized_info])}; "
    'name = WordCover; sourceTree = "<group>"; }',
)
ocr_group = add(
    "group:ocr",
    f"{{isa = PBXGroup; children = {entries([file_refs[p] for p in source_paths + headers if p.startswith('OCR/')] + [models_ref, licenses_ref])}; "
    'name = OCR; sourceTree = "<group>"; }',
)
products_group = add(
    "group:products",
    f'{{isa = PBXGroup; children = {entries([product_ref, *test_products.values()])}; name = Products; sourceTree = "<group>"; }}',
)
main_group = add(
    "group:main",
    f'{{isa = PBXGroup; children = {entries([app_group, ocr_group, tests_group, products_group, asset_catalog_ref])}; sourceTree = "<group>"; }}',
)

sources_phase = add(
    "phase:sources",
    f"{{isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = {entries(build_files)}; runOnlyForDeploymentPostprocessing = 0; }}",
)
resources_phase = add(
    "phase:resources",
    f"{{isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = {entries([models_build, licenses_build, localized_info_build, asset_catalog_build])}; runOnlyForDeploymentPostprocessing = 0; }}",
)
opencv_package = add(
    "package:opencv",
    '{isa = XCRemoteSwiftPackageReference; repositoryURL = "https://github.com/yeatse/opencv-spm.git"; requirement = {kind = exactVersion; version = 4.13.0; }; }',
)
opencv_product = add(
    "packageproduct:opencv",
    f'{{isa = XCSwiftPackageProductDependency; package = {opencv_package}; productName = OpenCV; }}',
)
opencv_build = add("build:opencv", f"{{isa = PBXBuildFile; productRef = {opencv_product}; }}")
frameworks_phase = add(
    "phase:frameworks",
    f'{{isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = ({opencv_build}); runOnlyForDeploymentPostprocessing = 0; }}',
)


def settings(values: dict[str, str | list[str]]) -> str:
    lines = []
    for key, value in values.items():
        if isinstance(value, list):
            rendered = "( " + ", ".join(q(v) for v in value) + " )"
        else:
            rendered = q(value)
        lines.append(f"{q(key)} = {rendered};")
    return "{ " + " ".join(lines) + " }"


common_project = {
    "CLANG_ENABLE_MODULES": "YES",
    "CLANG_ENABLE_OBJC_ARC": "YES",
    "IPHONEOS_DEPLOYMENT_TARGET": "17.0",
    "SDKROOT": "iphoneos",
    "SWIFT_VERSION": "5.0",
}
common_target = {
    "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
    "CODE_SIGN_STYLE": "Automatic",
    "GENERATE_INFOPLIST_FILE": "YES",
    "INFOPLIST_KEY_NSCameraUsageDescription": "拍摄要制作成学习卡片的图片。",
    "INFOPLIST_KEY_UIApplicationSceneManifest_Generation": "YES",
    "INFOPLIST_KEY_UILaunchScreen_Generation": "YES",
    "INFOPLIST_KEY_CFBundleDisplayName": "挡住单词",
    "INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad": "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight",
    "INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone": "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight",
    "IPHONEOS_DEPLOYMENT_TARGET": "17.0",
    "PRODUCT_BUNDLE_IDENTIFIER": "com.example.WordCover",
    "PRODUCT_NAME": "$(TARGET_NAME)",
    "SWIFT_OBJC_BRIDGING_HEADER": "OCR/OCR-Bridging-Header.h",
    "SWIFT_VERSION": "5.0",
    "TARGETED_DEVICE_FAMILY": "1,2",
    "SUPPORTED_PLATFORMS": "iphoneos iphonesimulator",
    "CLANG_CXX_LANGUAGE_STANDARD": "gnu++20",
    "ENABLE_USER_SCRIPT_SANDBOXING": "NO",
    "HEADER_SEARCH_PATHS": [
        "$(inherited)",
        "$(SRCROOT)/OCR/PaddleOCR/Engine",
        "$(SRCROOT)/OCR/PaddleOCR/ThirdParty/Clipper1",
        "$(PODS_ROOT)/onnxruntime-objc/objectivec",
        "$(PODS_ROOT)/onnxruntime-objc/objectivec/include",
    ],
    "OTHER_LDFLAGS": ["$(inherited)", "-Wl,-no_warn_duplicate_libraries"],
}
project_configs = []
target_configs = []
for kind in ("Debug", "Release"):
    project_configs.append(
        add(
            "config:project:" + kind,
            f"{{isa = XCBuildConfiguration; buildSettings = {settings({**common_project, 'SWIFT_OPTIMIZATION_LEVEL': '-Onone' if kind == 'Debug' else '-O', 'ONLY_ACTIVE_ARCH': 'YES' if kind == 'Debug' else 'NO', 'ENABLE_TESTABILITY': 'YES' if kind == 'Debug' else 'NO', 'SWIFT_ACTIVE_COMPILATION_CONDITIONS': 'DEBUG' if kind == 'Debug' else ''})}; name = {kind}; }}",
        )
    )
    target_configs.append(
        add(
            "config:target:" + kind,
            f"{{isa = XCBuildConfiguration; buildSettings = {settings(common_target)}; name = {kind}; }}",
        )
    )
project_config_list = add(
    "configlist:project",
    f"{{isa = XCConfigurationList; buildConfigurations = {entries(project_configs)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; }}",
)
target_config_list = add(
    "configlist:target",
    f"{{isa = XCConfigurationList; buildConfigurations = {entries(target_configs)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; }}",
)
target = add(
    "target:app",
    f"{{isa = PBXNativeTarget; buildConfigurationList = {target_config_list}; "
    f"buildPhases = {entries([sources_phase, frameworks_phase, resources_phase])}; "
    f"buildRules = (); dependencies = (); packageProductDependencies = ({opencv_product}); name = WordCover; productName = WordCover; "
    f"productReference = {product_ref}; productType = {q('com.apple.product-type.application')}; }}",
)

test_targets = {}
for name in test_refs:
    is_ui = name == "WordCoverUITests"
    test_source = add("build:" + name, f"{{isa = PBXBuildFile; fileRef = {test_refs[name]}; }}")
    test_sources = add("sources:" + name, f"{{isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({test_source}); runOnlyForDeploymentPostprocessing = 0; }}")
    test_frameworks = add("frameworks:" + name, "{isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; }")
    fixture_builds = [] if is_ui else [add("build:fixtures", f"{{isa = PBXBuildFile; fileRef = {fixtures_ref}; }}")]
    test_resources = add("resources:" + name, f"{{isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = {entries(fixture_builds)}; runOnlyForDeploymentPostprocessing = 0; }}")
    test_settings = {
        "CODE_SIGN_STYLE": "Automatic",
        "GENERATE_INFOPLIST_FILE": "YES",
        "IPHONEOS_DEPLOYMENT_TARGET": "17.0",
        "PRODUCT_BUNDLE_IDENTIFIER": "com.example." + name,
        "PRODUCT_NAME": "$(TARGET_NAME)",
        "SWIFT_VERSION": "5.0",
        "TARGETED_DEVICE_FAMILY": "1,2",
        "SUPPORTED_PLATFORMS": "iphoneos iphonesimulator",
    }
    if is_ui:
        test_settings["TEST_TARGET_NAME"] = "WordCover"
    else:
        test_settings["TEST_HOST"] = "$(BUILT_PRODUCTS_DIR)/WordCover.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/WordCover"
        test_settings["BUNDLE_LOADER"] = "$(TEST_HOST)"
    configs = [add("config:" + name + kind, f"{{isa = XCBuildConfiguration; buildSettings = {settings(test_settings)}; name = {kind}; }}") for kind in ("Debug", "Release")]
    config_list = add("configlist:" + name, f"{{isa = XCConfigurationList; buildConfigurations = {entries(configs)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; }}")
    proxy = add("proxy:" + name, f'{{isa = PBXContainerItemProxy; containerPortal = {ident("project")}; proxyType = 1; remoteGlobalIDString = {target}; remoteInfo = WordCover; }}')
    dependency = add("dependency:" + name, f"{{isa = PBXTargetDependency; target = {target}; targetProxy = {proxy}; }}")
    product_type = "com.apple.product-type.bundle.ui-testing" if is_ui else "com.apple.product-type.bundle.unit-test"
    test_targets[name] = add("target:" + name, f"{{isa = PBXNativeTarget; buildConfigurationList = {config_list}; buildPhases = {entries([test_sources, test_frameworks, test_resources])}; buildRules = (); dependencies = ({dependency}); name = {name}; productName = {name}; productReference = {test_products[name]}; productType = {q(product_type)}; }}")
project = add(
    "project",
    f"{{isa = PBXProject; attributes = {{BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 1600; "
    f"TargetAttributes = {{{target} = {{CreatedOnToolsVersion = 16.0; }}; }}; }}; "
    f"buildConfigurationList = {project_config_list}; compatibilityVersion = {q('Xcode 15.0')}; "
    f"developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, Base, \"zh-Hans\"); "
    f"mainGroup = {main_group}; productRefGroup = {products_group}; projectDirPath = {q('')}; "
    f"projectRoot = {q('')}; packageReferences = ({opencv_package}); targets = {entries([target, *test_targets.values()])}; }}",
)

PROJECT.mkdir(exist_ok=True)
body = "\n".join(f"\t\t{key} = {value};" for key, value in sorted(objects.items()))
(PROJECT / "project.pbxproj").write_text(
    "// !$*UTF8*$!\n{\n\tarchiveVersion = 1;\n\tclasses = {};\n"
    f"\tobjectVersion = 60;\n\tobjects = {{\n{body}\n\t}};\n"
    f"\trootObject = {project};\n}}\n"
)
print(f"Generated {PROJECT / 'project.pbxproj'} with {len(source_paths)} source files")

def buildable(target_id: str, name: str, product: str) -> str:
    return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target_id}" BuildableName="{product}" BlueprintName="{name}" ReferencedContainer="container:WordCover.xcodeproj"/>'

app_buildable = buildable(target, "WordCover", "WordCover.app")
test_buildables = {name: buildable(target_id, name, name + ".xctest") for name, target_id in test_targets.items()}
scheme_dir = PROJECT / "xcshareddata" / "xcschemes"
scheme_dir.mkdir(parents=True, exist_ok=True)
(scheme_dir / "WordCover.xcscheme").write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2700" version="1.3">
  <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries>
    <BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{app_buildable}</BuildActionEntry>
    {''.join(f'<BuildActionEntry buildForTesting="YES" buildForRunning="NO" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="YES">{ref}</BuildActionEntry>' for ref in test_buildables.values())}
  </BuildActionEntries></BuildAction>
  <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables>
    {''.join(f'<TestableReference skipped="NO" parallelizable="NO">{ref}</TestableReference>' for ref in test_buildables.values())}
  </Testables></TestAction>
  <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{app_buildable}</BuildableProductRunnable></LaunchAction>
  <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" useCustomWorkingDirectory="NO"><BuildableProductRunnable runnableDebuggingMode="0">{app_buildable}</BuildableProductRunnable></ProfileAction>
  <AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
''')
