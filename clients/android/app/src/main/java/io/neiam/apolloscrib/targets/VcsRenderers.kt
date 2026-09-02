package io.neiam.apolloscrib.targets

import io.neiam.apolloscrib.R
import io.neiam.apolloscrib.types.GithubCondensed
import io.neiam.apolloscrib.types.GitlabCondensed
import io.neiam.apolloscrib.types.SourceType
import io.neiam.apolloscrib.types.VisionEntry

/**
 * Whether the build is broken.
 *
 * The one thing a glance wants from CI, so the outcome is the glyph rather
 * than a word in a list: a tick, a cross, or a dot for anything still running
 * or waiting.
 */
internal fun ciGlyph(status: String?): Int = when (status?.lowercase()) {
    "success", "passed", "completed" -> R.drawable.fa_circle_check
    "failed", "failure", "canceled", "cancelled" -> R.drawable.fa_circle_xmark
    else -> R.drawable.fa_circle_info
}

object GitlabRenderer : SourceRenderer {

    override val type = SourceType.Gitlab
    override val iconRes = R.drawable.fa_code_branch
    override val label = "Apollo's Crib: GitLab"
    override val description = "Recent CI jobs from a GitLab query in one of your visions"

    override fun preview(entry: VisionEntry): List<Preview> {
        val jobs = entry.decode<List<GitlabCondensed>>().orEmpty()

        return listOf(
            Preview(
                id = entry.key,
                title = entry.label(),
                subtitle = jobs.firstOrNull()?.let { job ->
                    listOfNotNull(job.name, job.status).joinToString(" · ")
                },
                iconRes = iconRes,
                rows = jobs.map { job ->
                    Row(
                        iconRes = ciGlyph(job.status),
                        text = listOfNotNull(job.name, job.ref).joinToString(" "),
                        stamps = listOfNotNull(
                            job.status?.let { Stamp(R.drawable.fa_code_branch, it) }
                        )
                    )
                },
                empty = "No jobs"
            )
        )
    }
}

object GithubRenderer : SourceRenderer {

    override val type = SourceType.Github
    override val iconRes = R.drawable.fa_github
    override val label = "Apollo's Crib: GitHub"
    override val description = "Recent runs from a GitHub query in one of your visions"

    override fun preview(entry: VisionEntry): List<Preview> {
        val runs = entry.decode<List<GithubCondensed>>().orEmpty()

        return listOf(
            Preview(
                id = entry.key,
                title = entry.label(),
                subtitle = runs.firstOrNull()?.let { run ->
                    listOfNotNull(run.repository?.name, run.outcome()).joinToString(" · ")
                },
                iconRes = iconRes,
                rows = runs.map { run ->
                    Row(
                        iconRes = ciGlyph(run.outcome()),
                        text = listOfNotNull(
                            run.display_title ?: run.name,
                            run.head_branch
                        ).joinToString(" "),
                        stamps = listOfNotNull(
                            run.outcome()?.let { Stamp(R.drawable.fa_github, it) }
                        )
                    )
                },
                empty = "No runs"
            )
        )
    }

    /** A run that has finished says so in `conclusion`; one still going, in `status`. */
    private fun GithubCondensed.outcome(): String? = conclusion ?: status
}
