allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    afterEvaluate {
        if (plugins.hasPlugin("com.android.application") || plugins.hasPlugin("com.android.library")) {
            val android = extensions.findByName("android") as? com.android.build.api.dsl.ApplicationExtension
            android?.compileSdk = 36
        }
    }

    // Force Google Play Billing Library >= 8.0.0 (required by Google Play from Aug 2026)
    configurations.all {
        resolutionStrategy.eachDependency {
            if (requested.group == "com.android.billingclient" && requested.name == "billing") {
                useVersion("9.0.0")
            }
        }
    }

    project.evaluationDependsOn(":app")
}


tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

