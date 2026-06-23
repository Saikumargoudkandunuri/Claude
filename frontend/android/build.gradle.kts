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
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Force ALL plugins (subprojects) to use compileSdk 36.
// Fixes: ":file_picker is currently compiled against android-34" error.
subprojects {
    afterEvaluate {
        if (project.hasProperty("android")) {
            val android = project.extensions.findByName("android")
            if (android is com.android.build.gradle.BaseExtension) {
                if (android.compileSdkVersion != "android-36") {
                    android.compileSdkVersion(36)
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
