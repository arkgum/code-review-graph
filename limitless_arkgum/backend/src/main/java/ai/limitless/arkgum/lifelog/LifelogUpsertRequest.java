package ai.limitless.arkgum.lifelog;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.databind.JsonNode;
import jakarta.validation.constraints.NotBlank;
import java.time.Instant;

/**
 * Incoming lifelog payload from the iOS app. Field names match the Swift {@code Lifelog}
 * Codable encoding. {@code contents} arrives as an arbitrary JSON tree and is stored verbatim.
 */
public record LifelogUpsertRequest(
        @NotBlank String id,
        String title,
        String markdown,
        Instant startTime,
        Instant endTime,
        @JsonProperty("isStarred") boolean starred,
        Instant updatedAt,
        JsonNode contents
) {
}
