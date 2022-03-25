import java.io.File
import java.text.SimpleDateFormat
import java.util.*

val currentDir = File("../blog_sketch")

data class Config(
    val title: String,
    val date: Date,
    val path: String,
) {
    companion object {
        private const val kTitle = "title" // 标题
        private const val kDate = "date" // 创建时间
        private const val kUpdated = "updated" // 更新时间

        operator fun invoke(file: File, pathLen: Int): Config {
            val lines = file.readLines()
            val filePath = file.invariantSeparatorsPath.drop(pathLen)

            val configs = if (lines.first().trim() == "---") {
                lines.drop(1).takeWhile { l -> l.trim() != "---" }.associate { l ->
                    l.split(":").let { e -> e.first().trim() to e.last().trim() }
                }
            } else {
                println("${file.path} | 配置解析失败")
                mapOf()
            }

            return Config(
                configs[kTitle] ?: file.nameWithoutExtension,
                kotlin.runCatching { SimpleDateFormat("yyyy.MM.dd").parse(configs[kUpdated] ?: configs[kDate]) }
                    .getOrElse {
                        println("${file.canonicalPath} | 创建时间解析失败")
                        Date()
                    },
                filePath
            )
        }
    }
}

fun getPostListFile(dir:File):File? {
    val listFile = File(dir, if (dir == currentDir) "README.md" else "${dir.name}.md")

    if (!listFile.exists()) {
        if(!listFile.createNewFile()) {
            println("${listFile.canonicalPath} |创建失败")
            return null
        }
        File(dir, if (dir == currentDir) "README.tmp" else "${dir.name}.tmp").let {
            if (it.exists()) {
                listFile.writeBytes(it.readBytes())
            }
        }
    }
    return listFile
}

fun createPostList(dir: File, children: List<File>) {
    val listFile = getPostListFile(dir) ?: return
    listFile.appendText(
        """


        ## posts
        
        |posts|date|
        |:-|-:|
        
    """.trimIndent()
    )

    children.map { Config(it, dir.invariantSeparatorsPath.length + 1) }
        .sortedByDescending(Config::date)
        .forEach {
            listFile.appendText("|[${it.title}](${it.path})|${SimpleDateFormat("yyyy.MM.dd").format(it.date)}|\n")
        }
}

fun createTagList(dir: File, tags: List<File>) {
    val listFile = getPostListFile(dir) ?: return

    listFile.appendText(
        """
        
        
        ## tags
        
        
    """.trimIndent()
    )

    listFile.appendText(
        tags.joinToString() {
            it.invariantSeparatorsPath.drop(dir.invariantSeparatorsPath.length + 1).let { path ->
                "[$path]($path/${it.name}.md)"
            }
        }
    )
}

fun repoList(dir: File) {
    if(dir != currentDir) return
    val listFile = getPostListFile(dir) ?: return
    listFile.appendText(
        """
        
        
        ## Repository
        
        
    """.trimIndent()
    )

    listFile.appendText(
    """
    
    - [android demos](https://lzyprime.top/android_demos)
    - [flutter demos](https://lzyprime.top/flutter_demos)


    """.trimIndent()
    )
}

fun dfsDir(dir: File, tags: MutableList<File>): List<File> {
    File(dir, if (dir == currentDir) "README.md" else "${dir.name}.md").let {
        if (it.exists()) {
            it.delete()
        }
    }

    val curTags = mutableListOf<File>()
    val children = dir.listFiles().orEmpty().filter { !it.isHidden && it.isDirectory }
        .fold(dir.listFiles().orEmpty().filter { it.name.endsWith(".md") }.toMutableList()) { acc, d ->
            val dfsRes = dfsDir(d, curTags)
            if (dfsRes.isNotEmpty()) {
                curTags += d
            }
            acc += dfsRes
            acc
        }

    if(dir == currentDir) {
        repoList(dir)
    }

    if (curTags.isNotEmpty()) {
        createTagList(dir, curTags)
        tags += curTags
    }

    if (children.isNotEmpty()) {
        createPostList(dir, children)
    }

    return children
}

dfsDir(currentDir, mutableListOf())