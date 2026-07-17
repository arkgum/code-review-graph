package ai.limitless.arkgum.lifelog;

import com.fasterxml.jackson.databind.JsonNode;
import jakarta.validation.Valid;
import java.time.Instant;
import java.util.List;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Receives lifelogs synced from the iOS app.
 *
 * <p>{@code POST /api/lifelogs} performs an idempotent bulk upsert keyed by {@code id}, so the
 * client's outbox can safely re-send a batch after a network failure without creating duplicates.
 */
@RestController
@RequestMapping("/api/lifelogs")
public class LifelogController {

    private final LifelogRepository repository;

    public LifelogController(LifelogRepository repository) {
        this.repository = repository;
    }

    public record UpsertResult(int received, int inserted, int updated) {
    }

    @PostMapping
    @Transactional
    public UpsertResult upsert(@Valid @RequestBody List<LifelogUpsertRequest> requests) {
        int inserted = 0;
        int updated = 0;
        Instant now = Instant.now();

        for (LifelogUpsertRequest req : requests) {
            LifelogEntity entity = repository.findById(req.id()).orElse(null);
            if (entity == null) {
                entity = new LifelogEntity(req.id());
                inserted++;
            } else {
                updated++;
            }
            apply(req, entity, now);
            repository.save(entity);
        }
        return new UpsertResult(requests.size(), inserted, updated);
    }

    @GetMapping("/count")
    public long count() {
        return repository.count();
    }

    private void apply(LifelogUpsertRequest req, LifelogEntity entity, Instant receivedAt) {
        entity.setTitle(req.title());
        entity.setMarkdown(req.markdown());
        entity.setStartTime(req.startTime());
        entity.setEndTime(req.endTime());
        entity.setStarred(req.starred());
        entity.setUpdatedAt(req.updatedAt());
        entity.setContentsJson(serializeContents(req.contents()));
        entity.setReceivedAt(receivedAt);
    }

    private String serializeContents(JsonNode contents) {
        return contents == null || contents.isNull() ? "[]" : contents.toString();
    }
}
