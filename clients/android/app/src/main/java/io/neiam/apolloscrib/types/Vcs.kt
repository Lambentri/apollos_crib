package io.neiam.apolloscrib.types

import kotlinx.serialization.Serializable

/**
 * A CI job. Mirrors the subset of `GitlabCondensed` worth a glance.
 *
 * The crate carries the whole GitLab jobs response; a Smartspace card has room
 * for what it is and whether it passed, so only those are named here. The
 * unnamed rest is ignored rather than dropped -- see the parser's
 * `ignoreUnknownKeys`.
 */
@Serializable
data class GitlabCondensed(
    val id: Long? = null,
    val name: String? = null,
    val stage: String? = null,
    val status: String? = null,
    val ref: String? = null,
    val web_url: String? = null,
    val commit: GitCommit? = null
)

@Serializable
data class GitCommit(
    val title: String? = null,
    val short_id: String? = null,
    val author_name: String? = null
)

/**
 * A GitHub event or run. The worker emits several shapes under one type, so
 * everything is optional and the renderer says whatever is there.
 */
@Serializable
data class GithubCondensed(
    val id: String? = null,
    val name: String? = null,
    val status: String? = null,
    val conclusion: String? = null,
    val event: String? = null,
    val head_branch: String? = null,
    val html_url: String? = null,
    val repository: GithubRepoRef? = null,
    val display_title: String? = null
)

@Serializable
data class GithubRepoRef(
    val name: String? = null,
    val full_name: String? = null
)
