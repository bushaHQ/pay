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

dependencies {
    // Runtime: none. The SDK ships zero transitive dependencies — it
    // relies only on the Kotlin stdlib, the Android framework, and the
    // JDK (HttpURLConnection, org.json).

    // Pure-JVM unit tests.
    testImplementation("junit:junit:4.13.2")
    // Real org.json for unit tests (the Android framework's copy is a
    // no-op stub under plain JVM tests). Test-only — not shipped.
    testImplementation("org.json:json:20240303")
    // Robolectric runs Android-framework tests (WebView, Dialog, etc.)
    // on the JVM — the Android equivalent of the Catalyst trick.
    testImplementation("org.robolectric:robolectric:4.14.1")
    testImplementation("androidx.test:core:1.6.1")
}

// Aggregated line-coverage report for the debug unit tests.
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
    executionData.setFrom(
        fileTree(project.layout.buildDirectory.get()) {
            include("**/testDebugUnitTest.exec")
        }
    )
}
