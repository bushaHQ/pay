plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
    jacoco
}

android {
    namespace = "co.busha.pay"
    compileSdk = 35

    defaultConfig {
        minSdk = 21
        consumerProguardFiles("consumer-rules.pro")
    }

    buildTypes {
        debug {
            // Instruments the debug variant so `testDebugUnitTest`
            // emits JaCoCo execution data for the coverage report.
            enableUnitTestCoverage = true
        }
        release {
            isMinifyEnabled = false
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    testOptions {
        unitTests {
            isIncludeAndroidResources = true
        }
    }
}

tasks.withType<Test>().configureEach {
    configure<JacocoTaskExtension> {
        isIncludeNoLocationClasses = true
        excludes = listOf("jdk.internal.*")
    }
    doNotTrackState("produces JaCoCo execution data the build cache can't restore")
}

dependencies {
    implementation("androidx.webkit:webkit:1.12.1")

    // Pure-JVM unit tests.
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.json:json:20240303")
    testImplementation("org.robolectric:robolectric:4.14.1")
    testImplementation("androidx.test:core:1.6.1")
}

tasks.register<JacocoReport>("jacocoTestReport") {
    dependsOn("testDebugUnitTest")
    reports {
        xml.required.set(true)
        html.required.set(true)
    }
    val mainSrc = "${project.projectDir}/src/main/kotlin"
    sourceDirectories.setFrom(files(mainSrc))
    classDirectories.setFrom(
        fileTree("${project.layout.buildDirectory.get()}/tmp/kotlin-classes/debug")
    )
    // Point at the exact exec file (emitted by enableUnitTestCoverage)
    // rather than scanning all of build/ — a broad fileTree would
    // overlap other tasks' outputs and trip Gradle's implicit-
    // dependency validation.
    executionData.setFrom(
        project.layout.buildDirectory.file(
            "outputs/unit_test_code_coverage/debugUnitTest/testDebugUnitTest.exec",
        )
    )
}
